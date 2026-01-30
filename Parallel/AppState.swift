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

    let instanceManager = ClaudeInstanceManager()
    let gitManager = GitManager()
    let buildRunner = BuildRunner()

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

    var totalChangedFiles: Int {
        instances.reduce(0) { $0 + $1.changedFiles.count }
    }

    init() {
        setupBindings()
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

    func createInstance(name: String, task: String, branchName: String?) async {
        guard let project = currentProject else { return }

        let branch = branchName ?? "claude/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(UUID().uuidString.prefix(6))"

        let instance = ClaudeInstance(
            name: name,
            task: task,
            projectPath: project.path,
            branchName: branch
        )

        await instanceManager.startInstance(instance, gitManager: gitManager)
    }

    func stopInstance(_ instance: ClaudeInstance) {
        instanceManager.stopInstance(instance)
    }

    func stopAllInstances() {
        instanceManager.stopAllInstances()
    }

    func runBuildIfAllReady() async {
        guard allInstancesReady, let project = currentProject else { return }

        isRunningBuild = true
        buildOutput = ""

        do {
            let output = try await buildRunner.runBuild(command: project.buildCommand)
            buildOutput = output
        } catch {
            buildOutput = "Build failed: \(error.localizedDescription)"
        }

        isRunningBuild = false
    }

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
}
