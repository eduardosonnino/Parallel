import Foundation

actor GitManager {
    private var projectPath: URL?

    func setProjectPath(_ path: URL) {
        self.projectPath = path
    }

    func runGitCommand(_ arguments: [String]) async throws -> String {
        guard let projectPath = projectPath else {
            throw GitError.noProjectPath
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = projectPath
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GitError.commandFailed(errorOutput)
        }

        return String(data: outputData, encoding: .utf8) ?? ""
    }

    func createBranch(_ branchName: String) async throws {
        _ = try await runGitCommand(["checkout", "-b", branchName])
    }

    func checkoutBranch(_ branchName: String) async throws {
        _ = try await runGitCommand(["checkout", branchName])
    }

    func deleteBranch(_ branchName: String, force: Bool = false) async throws {
        let flag = force ? "-D" : "-d"
        _ = try await runGitCommand(["branch", flag, branchName])
    }

    func getCurrentBranch() async throws -> String {
        let output = try await runGitCommand(["branch", "--show-current"])
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func getAllBranches() async throws -> [GitBranch] {
        let output = try await runGitCommand(["branch", "-a", "-v"])
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> GitBranch? in
            let isCurrent = line.hasPrefix("*")
            let cleanLine = line.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "* ", with: "")

            let parts = cleanLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2 else { return nil }

            let name = parts[0]
            let isRemote = name.hasPrefix("remotes/")
            let lastCommit = parts.count > 1 ? parts[1] : nil

            return GitBranch(
                name: name,
                isRemote: isRemote,
                isCurrent: isCurrent,
                lastCommit: lastCommit
            )
        }
    }

    func getChangedFiles(for branchName: String? = nil) async throws -> [GitChange] {
        let output = try await runGitCommand(["status", "--porcelain=v1"])
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> GitChange? in
            guard line.count >= 3 else { return nil }

            let statusCode = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            let filePath = String(line.dropFirst(3))

            let changeType: GitChangeType
            switch statusCode.first {
            case "A": changeType = .added
            case "M": changeType = .modified
            case "D": changeType = .deleted
            case "R": changeType = .renamed
            case "C": changeType = .copied
            case "?": changeType = .untracked
            case "!": changeType = .ignored
            default: changeType = .modified
            }

            return GitChange(
                filePath: filePath,
                changeType: changeType
            )
        }
    }

    func getCommits(for branchName: String, limit: Int = 50) async throws -> [GitCommit] {
        let format = "%H|%s|%an|%aI"
        let output = try await runGitCommand([
            "log",
            branchName,
            "-n", String(limit),
            "--format=\(format)"
        ])

        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> GitCommit? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 4 else { return nil }

            let dateFormatter = ISO8601DateFormatter()
            let date = dateFormatter.date(from: parts[3]) ?? Date()

            return GitCommit(
                id: parts[0],
                message: parts[1],
                author: parts[2],
                date: date,
                filesChanged: 0
            )
        }
    }

    func getFileDiff(_ filePath: String) async throws -> String {
        return try await runGitCommand(["diff", "--", filePath])
    }

    func stageFile(_ filePath: String) async throws {
        _ = try await runGitCommand(["add", filePath])
    }

    func stageAllFiles() async throws {
        _ = try await runGitCommand(["add", "-A"])
    }

    func unstageFile(_ filePath: String) async throws {
        _ = try await runGitCommand(["reset", "HEAD", "--", filePath])
    }

    func commitChanges(for instance: ClaudeInstance, message: String) async {
        do {
            try await checkoutBranch(instance.branchName)
            try await stageAllFiles()
            _ = try await runGitCommand(["commit", "-m", message])
        } catch {
            print("Failed to commit changes for \(instance.name): \(error)")
        }
    }

    func commitAllChanges(files: [GitChange], message: String) async {
        do {
            for file in files {
                try await stageFile(file.filePath)
            }
            _ = try await runGitCommand(["commit", "-m", message])
        } catch {
            print("Failed to commit all changes: \(error)")
        }
    }

    func pushBranch(_ branchName: String) async {
        do {
            _ = try await runGitCommand(["push", "-u", "origin", branchName])
        } catch {
            print("Failed to push branch \(branchName): \(error)")
        }
    }

    func pullBranch(_ branchName: String) async throws {
        _ = try await runGitCommand(["pull", "origin", branchName])
    }

    func mergeBranch(_ sourceBranch: String, into targetBranch: String) async {
        do {
            try await checkoutBranch(targetBranch)
            _ = try await runGitCommand(["merge", sourceBranch])
        } catch {
            print("Failed to merge \(sourceBranch) into \(targetBranch): \(error)")
        }
    }

    func squashMergeAll(instances: [ClaudeInstance]) async {
        for instance in instances where instance.status == .completed {
            do {
                try await checkoutBranch("main")
                _ = try await runGitCommand(["merge", "--squash", instance.branchName])
                _ = try await runGitCommand(["commit", "-m", "Squash merge: \(instance.name) - \(instance.task)"])
            } catch {
                print("Failed to squash merge \(instance.branchName): \(error)")
            }
        }
    }

    func hasUncommittedChanges() async throws -> Bool {
        let output = try await runGitCommand(["status", "--porcelain"])
        return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func getConflicts() async throws -> [MergeConflict] {
        let output = try await runGitCommand(["diff", "--name-only", "--diff-filter=U"])
        let files = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        return files.map { filePath in
            MergeConflict(
                filePath: filePath,
                sourceBranch: "",
                targetBranch: ""
            )
        }
    }

    func abortMerge() async throws {
        _ = try await runGitCommand(["merge", "--abort"])
    }

    func resolveConflict(_ conflict: MergeConflict, resolution: ConflictResolution) async throws {
        switch resolution {
        case .useOurs:
            _ = try await runGitCommand(["checkout", "--ours", "--", conflict.filePath])
        case .useTheirs:
            _ = try await runGitCommand(["checkout", "--theirs", "--", conflict.filePath])
        case .manual:
            break
        }
        try await stageFile(conflict.filePath)
    }
}

enum GitError: LocalizedError {
    case noProjectPath
    case commandFailed(String)
    case branchNotFound(String)
    case mergeConflict

    var errorDescription: String? {
        switch self {
        case .noProjectPath:
            return "No project path set"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        case .branchNotFound(let branch):
            return "Branch not found: \(branch)"
        case .mergeConflict:
            return "Merge conflict detected"
        }
    }
}

enum ConflictResolution {
    case useOurs
    case useTheirs
    case manual
}
