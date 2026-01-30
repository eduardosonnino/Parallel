import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentProject: Project?
    @Published var instances: [ClaudeInstance] = []
    @Published var selectedInstanceId: UUID?
    @Published var showNewInstanceSheet = false
    @Published var isRunningBuild = false
    @Published var buildOutput: String = ""
    @Published var commitStrategy: CommitStrategy = .separateBranches
    @Published var defaultIsolationMode: IsolationMode = .worktree
    @Published var pendingMerges: [UUID] = []

    let instanceManager = ClaudeInstanceManager()
    let gitManager = GitManager()
    let buildRunner = BuildRunner()
    let worktreeManager = WorktreeManager()
    let orchestrator = Orchestrator()

    private var cancellables = Set<AnyCancellable>()

    var selectedInstance: ClaudeInstance? {
        instances.first { $0.id == selectedInstanceId }
    }

    var allInstancesReady: Bool {
        !instances.isEmpty && instances.allSatisfy { $0.status == .ready || $0.status == .completed }
    }

    var readyInstancesCount: Int {
        instances.filter { $0.status == .ready || $0.status == .completed }.count
    }

    var completedUnmergedInstances: [ClaudeInstance] {
        instances.filter { $0.status == .completed && !$0.isMerged && $0.isolationMode == .worktree }
    }

    var totalChangedFiles: Int {
        instances.reduce(0) { $0 + $1.changedFiles.count }
    }

    var canBuildMainProject: Bool {
        // Main project is always buildable when using isolated worktrees
        // Only instances working in shared mode can affect buildability
        let sharedActiveInstances = instances.filter {
            $0.isolationMode == .shared && $0.status.isActive
        }
        return sharedActiveInstances.isEmpty
    }

    init() {
        setupBindings()
        orchestrator.setAppState(self)
    }

    private func setupBindings() {
        instanceManager.$instances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] instances in
                self?.instances = instances
            }
            .store(in: &cancellables)
    }

    func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your project folder"

        if panel.runModal() == .OK, let url = panel.url {
            loadProject(at: url)
        }
    }

    func loadProject(at url: URL) {
        let project = Project(
            name: url.lastPathComponent,
            path: url,
            buildCommand: detectBuildCommand(at: url)
        )
        currentProject = project
        gitManager.setProjectPath(url)
        buildRunner.setProjectPath(url)
        worktreeManager.setProjectPath(url)
    }

    private func detectBuildCommand(at url: URL) -> String {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: url.appendingPathComponent("package.json").path) {
            return "npm run build"
        } else if fileManager.fileExists(atPath: url.appendingPathComponent("Cargo.toml").path) {
            return "cargo build"
        } else if fileManager.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            return "swift build"
        } else if fileManager.fileExists(atPath: url.appendingPathComponent("Makefile").path) {
            return "make"
        } else if fileManager.fileExists(atPath: url.appendingPathComponent("build.gradle").path) {
            return "./gradlew build"
        } else if fileManager.fileExists(atPath: url.appendingPathComponent("pom.xml").path) {
            return "mvn package"
        }

        return "echo 'No build command configured'"
    }

    func createInstance(name: String, task: String, branchName: String?, isolationMode: IsolationMode? = nil) async {
        guard let project = currentProject else { return }

        let mode = isolationMode ?? defaultIsolationMode
        let sanitizedName = name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        let branch = branchName ?? "claude/\(sanitizedName)-\(UUID().uuidString.prefix(6).lowercased())"

        var workingPath = project.path

        // Create isolated worktree if needed
        if mode == .worktree {
            do {
                let worktree = try await worktreeManager.createWorktree(name: sanitizedName, branch: branch)
                workingPath = worktree.path

                // Symlink or install dependencies
                try await worktreeManager.installDependencies(in: worktree)
            } catch {
                print("Failed to create worktree: \(error)")
                // Fall back to shared mode
                return
            }
        }

        let instance = ClaudeInstance(
            name: name,
            task: task,
            projectPath: project.path,
            workingPath: workingPath,
            branchName: branch,
            isolationMode: mode
        )

        await instanceManager.startInstance(instance, gitManager: gitManager)
    }

    func stopInstance(_ instance: ClaudeInstance) {
        instanceManager.stopInstance(instance)
    }

    func stopAllInstances() {
        instanceManager.stopAllInstances()
    }

    // MARK: - Build Management

    func runBuild() async {
        guard let project = currentProject else { return }

        isRunningBuild = true
        buildOutput = "Starting build...\n"

        do {
            let output = try await buildRunner.runBuild(command: project.buildCommand)
            buildOutput += output
            buildOutput += "\n\nBuild completed successfully!"
        } catch {
            buildOutput += "\nBuild failed: \(error.localizedDescription)"
        }

        isRunningBuild = false
    }

    func runBuildIfAllReady() async {
        guard allInstancesReady else { return }
        await runBuild()
    }

    // MARK: - Merge Management (Isolated Worktrees)

    func mergeInstance(_ instance: ClaudeInstance, squash: Bool = false) async {
        guard instance.isolationMode == .worktree,
              instance.status == .completed,
              !instance.isMerged else {
            return
        }

        do {
            let worktree = WorktreeManager.Worktree(
                id: instance.id,
                name: instance.name,
                path: instance.workingPath,
                branch: instance.branchName,
                isMain: false
            )

            try await worktreeManager.mergeWorktreeToMain(worktree, squash: squash)

            // Mark instance as merged
            instanceManager.markInstanceMerged(instance)

            buildOutput = "Merged '\(instance.name)' to main successfully.\n"
        } catch {
            buildOutput = "Failed to merge '\(instance.name)': \(error.localizedDescription)\n"
        }
    }

    func mergeAllCompleted(squash: Bool = false) async {
        for instance in completedUnmergedInstances {
            await mergeInstance(instance, squash: squash)
        }
    }

    func mergeAndBuild(_ instance: ClaudeInstance) async {
        await mergeInstance(instance)
        await runBuild()
    }

    // MARK: - Git Operations

    func commitAllChanges() async {
        switch commitStrategy {
        case .separateBranches:
            for instance in instances where !instance.changedFiles.isEmpty {
                await gitManager.commitChanges(
                    for: instance,
                    message: "[\(instance.name)] \(instance.task)"
                )
            }
        case .unifiedCommit:
            let allFiles = instances.flatMap { $0.changedFiles }
            if !allFiles.isEmpty {
                await gitManager.commitAllChanges(
                    files: allFiles,
                    message: "Parallel changes from \(instances.count) Claude instances"
                )
            }
        case .squashMerge:
            await gitManager.squashMergeAll(instances: instances)
        }
    }

    func pushAllChanges() async {
        for instance in instances {
            await gitManager.pushBranch(instance.branchName)
        }
    }

    func mergeAllToMain() async {
        for instance in instances where instance.status == .completed {
            await gitManager.mergeBranch(instance.branchName, into: "main")
        }
    }

    func refreshGitStatus() async {
        for instance in instances {
            await instanceManager.refreshInstanceGitStatus(instance, gitManager: gitManager)
        }
    }

    // MARK: - Cleanup

    func cleanupInstance(_ instance: ClaudeInstance) async {
        instanceManager.stopInstance(instance)

        if instance.isolationMode == .worktree {
            do {
                let worktree = WorktreeManager.Worktree(
                    id: instance.id,
                    name: instance.name,
                    path: instance.workingPath,
                    branch: instance.branchName,
                    isMain: false
                )
                try await worktreeManager.removeWorktree(worktree)
            } catch {
                print("Failed to cleanup worktree: \(error)")
            }
        }

        instanceManager.removeInstance(instance)
    }

    func cleanupAllMergedInstances() async {
        let mergedInstances = instances.filter { $0.isMerged }
        for instance in mergedInstances {
            await cleanupInstance(instance)
        }
    }
}
