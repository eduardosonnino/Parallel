import Foundation
import Combine

@MainActor
class ClaudeInstanceManager: ObservableObject {
    @Published var instances: [ClaudeInstance] = []

    private var processes: [UUID: Process] = [:]
    private var outputPipes: [UUID: Pipe] = [:]
    private var outputHandlers: [UUID: FileHandle] = [:]
    private var monitorTimers: [UUID: Timer] = [:]

    func startInstance(_ instance: ClaudeInstance, gitManager: GitManager) async {
        var newInstance = instance
        newInstance.status = .starting
        newInstance.startTime = Date()

        instances.append(newInstance)

        // For worktree mode, the branch is already created by WorktreeManager
        // For shared mode, we need to create and checkout the branch
        if instance.isolationMode == .shared {
            do {
                try await gitManager.createBranch(instance.branchName)
                try await gitManager.checkoutBranch(instance.branchName)
            } catch {
                updateInstance(id: newInstance.id) { inst in
                    inst.status = .error
                    inst.errorMessage = error.localizedDescription
                }
                return
            }
        }

        await launchClaudeProcess(for: newInstance)
    }

    private func launchClaudeProcess(for instance: ClaudeInstance) async {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "claude",
            "--print",
            "--dangerously-skip-permissions",
            instance.task
        ]

        // Use workingPath - this is the worktree path for isolated mode
        // or the main project path for shared mode
        process.currentDirectoryURL = instance.workingPath
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.environment = ProcessInfo.processInfo.environment

        processes[instance.id] = process
        outputPipes[instance.id] = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.appendOutput(for: instance.id, output: output)
                }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.appendOutput(for: instance.id, output: "[ERROR] \(output)")
                }
            }
        }

        do {
            try process.run()

            updateInstance(id: instance.id) { inst in
                inst.status = .running
                inst.processId = process.processIdentifier
            }

            startMonitoringProcess(for: instance.id, process: process)

        } catch {
            updateInstance(id: instance.id) { inst in
                inst.status = .error
                inst.errorMessage = error.localizedDescription
            }
        }
    }

    private func startMonitoringProcess(for instanceId: UUID, process: Process) {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                if !process.isRunning {
                    self.handleProcessCompletion(for: instanceId, process: process)
                }
            }
        }
        monitorTimers[instanceId] = timer
    }

    private func handleProcessCompletion(for instanceId: UUID, process: Process) {
        monitorTimers[instanceId]?.invalidate()
        monitorTimers.removeValue(forKey: instanceId)

        let exitCode = process.terminationStatus

        updateInstance(id: instanceId) { instance in
            instance.endTime = Date()
            if exitCode == 0 {
                instance.status = .completed
            } else if instance.status != .stopped {
                instance.status = .error
                instance.errorMessage = "Process exited with code \(exitCode)"
            }
        }

        cleanupProcess(for: instanceId)
    }

    func stopInstance(_ instance: ClaudeInstance) {
        if let process = processes[instance.id], process.isRunning {
            process.terminate()
        }

        updateInstance(id: instance.id) { inst in
            inst.status = .stopped
            inst.endTime = Date()
        }

        cleanupProcess(for: instance.id)
    }

    func stopAllInstances() {
        for instance in instances where instance.status.isActive {
            stopInstance(instance)
        }
    }

    private func cleanupProcess(for instanceId: UUID) {
        if let pipe = outputPipes[instanceId] {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        processes.removeValue(forKey: instanceId)
        outputPipes.removeValue(forKey: instanceId)
        outputHandlers.removeValue(forKey: instanceId)
    }

    func removeInstance(_ instance: ClaudeInstance) {
        stopInstance(instance)
        instances.removeAll { $0.id == instance.id }
    }

    func markInstanceReady(_ instance: ClaudeInstance) {
        updateInstance(id: instance.id) { inst in
            inst.status = .ready
        }
    }

    func markInstanceMerged(_ instance: ClaudeInstance) {
        updateInstance(id: instance.id) { inst in
            inst.isMerged = true
        }
    }

    func refreshInstanceGitStatus(_ instance: ClaudeInstance, gitManager: GitManager) async {
        do {
            let changes = try await gitManager.getChangedFiles(for: instance.branchName)
            let commits = try await gitManager.getCommits(for: instance.branchName)

            updateInstance(id: instance.id) { inst in
                inst.changedFiles = changes
                inst.commits = commits
            }
        } catch {
            print("Failed to refresh git status for \(instance.name): \(error)")
        }
    }

    private func appendOutput(for instanceId: UUID, output: String) {
        updateInstance(id: instanceId) { instance in
            instance.output += output
        }
    }

    private func updateInstance(id: UUID, update: (inout ClaudeInstance) -> Void) {
        if let index = instances.firstIndex(where: { $0.id == id }) {
            update(&instances[index])
        }
    }

    func sendInput(to instance: ClaudeInstance, input: String) {
        guard let process = processes[instance.id],
              process.isRunning,
              let stdin = process.standardInput as? Pipe else {
            return
        }

        if let data = (input + "\n").data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
    }

    func restartInstance(_ instance: ClaudeInstance, gitManager: GitManager) async {
        stopInstance(instance)

        var newInstance = instance
        newInstance.status = .idle
        newInstance.output = ""
        newInstance.startTime = nil
        newInstance.endTime = nil
        newInstance.errorMessage = nil
        newInstance.isMerged = false

        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = newInstance
        }

        await launchClaudeProcess(for: newInstance)
    }
}
