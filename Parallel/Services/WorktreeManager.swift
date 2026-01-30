import Foundation

actor WorktreeManager {
    private var projectPath: URL?
    private var worktreesBasePath: URL?

    struct Worktree: Identifiable, Equatable {
        let id: UUID
        let name: String
        let path: URL
        let branch: String
        let isMain: Bool

        var isValid: Bool {
            FileManager.default.fileExists(atPath: path.path)
        }
    }

    func setProjectPath(_ path: URL) {
        self.projectPath = path
        self.worktreesBasePath = path
            .deletingLastPathComponent()
            .appendingPathComponent("\(path.lastPathComponent)-worktrees")
    }

    func createWorktree(name: String, branch: String) async throws -> Worktree {
        guard let projectPath = projectPath,
              let basePath = worktreesBasePath else {
            throw WorktreeError.noProjectPath
        }

        // Create worktrees directory if needed
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: basePath.path) {
            try fileManager.createDirectory(at: basePath, withIntermediateDirectories: true)
        }

        let worktreePath = basePath.appendingPathComponent(name)

        // Create the worktree with a new branch
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "add", "-b", branch, worktreePath.path]
        process.currentDirectoryURL = projectPath

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WorktreeError.creationFailed(errorMessage)
        }

        return Worktree(
            id: UUID(),
            name: name,
            path: worktreePath,
            branch: branch,
            isMain: false
        )
    }

    func listWorktrees() async throws -> [Worktree] {
        guard let projectPath = projectPath else {
            throw WorktreeError.noProjectPath
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "list", "--porcelain"]
        process.currentDirectoryURL = projectPath
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        return parseWorktreeList(output)
    }

    private func parseWorktreeList(_ output: String) -> [Worktree] {
        var worktrees: [Worktree] = []
        var currentPath: String?
        var currentBranch: String?

        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("worktree ") {
                currentPath = String(line.dropFirst(9))
            } else if line.hasPrefix("branch ") {
                currentBranch = String(line.dropFirst(7))
                    .replacingOccurrences(of: "refs/heads/", with: "")
            } else if line.isEmpty, let path = currentPath {
                let url = URL(fileURLWithPath: path)
                let isMain = currentBranch == "main" || currentBranch == "master"

                worktrees.append(Worktree(
                    id: UUID(),
                    name: url.lastPathComponent,
                    path: url,
                    branch: currentBranch ?? "unknown",
                    isMain: isMain
                ))

                currentPath = nil
                currentBranch = nil
            }
        }

        return worktrees
    }

    func removeWorktree(_ worktree: Worktree) async throws {
        guard let projectPath = projectPath else {
            throw WorktreeError.noProjectPath
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["worktree", "remove", worktree.path.path, "--force"]
        process.currentDirectoryURL = projectPath

        try process.run()
        process.waitUntilExit()

        // Also delete the branch if it exists
        let branchProcess = Process()
        branchProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        branchProcess.arguments = ["branch", "-D", worktree.branch]
        branchProcess.currentDirectoryURL = projectPath

        try? branchProcess.run()
        branchProcess.waitUntilExit()
    }

    func mergeWorktreeToMain(_ worktree: Worktree, squash: Bool = false) async throws {
        guard let projectPath = projectPath else {
            throw WorktreeError.noProjectPath
        }

        // First, commit any uncommitted changes in the worktree
        try await commitWorktreeChanges(worktree)

        // Merge the branch into main
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")

        if squash {
            process.arguments = ["merge", "--squash", worktree.branch]
        } else {
            process.arguments = ["merge", worktree.branch, "--no-ff", "-m", "Merge \(worktree.name) from parallel Claude instance"]
        }

        process.currentDirectoryURL = projectPath

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WorktreeError.mergeFailed(errorMessage)
        }

        if squash {
            // For squash, we need to commit manually
            let commitProcess = Process()
            commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            commitProcess.arguments = ["commit", "-m", "Squash merge: \(worktree.name)"]
            commitProcess.currentDirectoryURL = projectPath

            try commitProcess.run()
            commitProcess.waitUntilExit()
        }
    }

    private func commitWorktreeChanges(_ worktree: Worktree) async throws {
        // Check for uncommitted changes
        let statusProcess = Process()
        let statusPipe = Pipe()

        statusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        statusProcess.arguments = ["status", "--porcelain"]
        statusProcess.currentDirectoryURL = worktree.path
        statusProcess.standardOutput = statusPipe

        try statusProcess.run()
        statusProcess.waitUntilExit()

        let statusData = statusPipe.fileHandleForReading.readDataToEndOfFile()
        let status = String(data: statusData, encoding: .utf8) ?? ""

        if !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Stage all changes
            let addProcess = Process()
            addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            addProcess.arguments = ["add", "-A"]
            addProcess.currentDirectoryURL = worktree.path

            try addProcess.run()
            addProcess.waitUntilExit()

            // Commit
            let commitProcess = Process()
            commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            commitProcess.arguments = ["commit", "-m", "Auto-commit from \(worktree.name)"]
            commitProcess.currentDirectoryURL = worktree.path

            try commitProcess.run()
            commitProcess.waitUntilExit()
        }
    }

    func syncWorktreeFromMain(_ worktree: Worktree) async throws {
        // Rebase the worktree branch on top of main
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rebase", "main"]
        process.currentDirectoryURL = worktree.path

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            // Abort rebase on failure
            let abortProcess = Process()
            abortProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            abortProcess.arguments = ["rebase", "--abort"]
            abortProcess.currentDirectoryURL = worktree.path

            try? abortProcess.run()
            abortProcess.waitUntilExit()

            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw WorktreeError.rebaseFailed(errorMessage)
        }
    }

    func getWorktreeStatus(_ worktree: Worktree) async throws -> WorktreeStatus {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["status", "--porcelain"]
        process.currentDirectoryURL = worktree.path
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        let modifiedCount = lines.filter { $0.hasPrefix(" M") || $0.hasPrefix("M ") }.count
        let addedCount = lines.filter { $0.hasPrefix("A ") || $0.hasPrefix("??") }.count
        let deletedCount = lines.filter { $0.hasPrefix(" D") || $0.hasPrefix("D ") }.count

        // Get ahead/behind count
        let aheadBehind = try await getAheadBehindMain(worktree)

        return WorktreeStatus(
            modifiedFiles: modifiedCount,
            addedFiles: addedCount,
            deletedFiles: deletedCount,
            commitsAhead: aheadBehind.ahead,
            commitsBehind: aheadBehind.behind,
            hasUncommittedChanges: !lines.isEmpty
        )
    }

    private func getAheadBehindMain(_ worktree: Worktree) async throws -> (ahead: Int, behind: Int) {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-list", "--left-right", "--count", "main...\(worktree.branch)"]
        process.currentDirectoryURL = worktree.path
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .compactMap { Int($0) }

        if parts.count >= 2 {
            return (ahead: parts[1], behind: parts[0])
        }

        return (ahead: 0, behind: 0)
    }

    func installDependencies(in worktree: Worktree) async throws {
        let fileManager = FileManager.default
        let packageJsonPath = worktree.path.appendingPathComponent("package.json").path

        guard fileManager.fileExists(atPath: packageJsonPath) else {
            return // No package.json, skip
        }

        // Check if node_modules exists in main project and symlink it
        // This saves disk space and install time
        if let projectPath = projectPath {
            let mainNodeModules = projectPath.appendingPathComponent("node_modules")
            let worktreeNodeModules = worktree.path.appendingPathComponent("node_modules")

            if fileManager.fileExists(atPath: mainNodeModules.path) &&
               !fileManager.fileExists(atPath: worktreeNodeModules.path) {
                try fileManager.createSymbolicLink(
                    at: worktreeNodeModules,
                    withDestinationURL: mainNodeModules
                )
                return
            }
        }

        // Fall back to running yarn/npm install
        let process = Process()
        process.currentDirectoryURL = worktree.path

        let yarnLockPath = worktree.path.appendingPathComponent("yarn.lock").path
        if fileManager.fileExists(atPath: yarnLockPath) {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["yarn", "install", "--frozen-lockfile"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["npm", "ci"]
        }

        try process.run()
        process.waitUntilExit()
    }
}

struct WorktreeStatus {
    let modifiedFiles: Int
    let addedFiles: Int
    let deletedFiles: Int
    let commitsAhead: Int
    let commitsBehind: Int
    let hasUncommittedChanges: Bool

    var totalChangedFiles: Int {
        modifiedFiles + addedFiles + deletedFiles
    }

    var isMergeable: Bool {
        !hasUncommittedChanges && commitsAhead > 0
    }

    var summary: String {
        var parts: [String] = []
        if commitsAhead > 0 {
            parts.append("\(commitsAhead) commit\(commitsAhead == 1 ? "" : "s") ahead")
        }
        if hasUncommittedChanges {
            parts.append("\(totalChangedFiles) uncommitted")
        }
        return parts.isEmpty ? "Clean" : parts.joined(separator: ", ")
    }
}

enum WorktreeError: LocalizedError {
    case noProjectPath
    case creationFailed(String)
    case mergeFailed(String)
    case rebaseFailed(String)
    case worktreeNotFound

    var errorDescription: String? {
        switch self {
        case .noProjectPath:
            return "No project path set"
        case .creationFailed(let message):
            return "Failed to create worktree: \(message)"
        case .mergeFailed(let message):
            return "Failed to merge: \(message)"
        case .rebaseFailed(let message):
            return "Failed to rebase: \(message)"
        case .worktreeNotFound:
            return "Worktree not found"
        }
    }
}
