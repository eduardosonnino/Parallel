//
//  CoordinatorService.swift
//  Parallel
//
//  Fast card creation with isolated code + preview per agent
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class CoordinatorService {
    private let claudeRunner = ClaudeCodeRunner.shared
    weak var canvasState: CanvasState?

    private let names = ["Atlas", "Nova", "Cipher", "Pulse", "Echo", "Nexus", "Quantum", "Vector"]
    private var usedNames: Set<String> = []

    init() {
        claudeRunner.onOutput = { [weak self] id, output in
            guard let instance = self?.canvasState?.instance(for: id) else { return }
            let clean = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.count > 5 {
                instance.addMessage(role: .assistant, content: clean)
            }
        }

        claudeRunner.onProcessCompleted = { [weak self] id, code in
            guard let instance = self?.canvasState?.instance(for: id) else { return }
            instance.status = code == 0 ? .completed : .error

            // Record completion to version history
            if code == 0, let projectPath = instance.mainRepoPath {
                PersistenceService.shared.recordAction(
                    agentId: instance.id,
                    agentName: instance.displayName,
                    action: "completed",
                    summary: "Completed task: \(instance.task)",
                    filesChanged: [],
                    projectPath: projectPath
                )
            }
        }
    }

    /// Instant card creation with isolated environment
    @discardableResult
    func startCoordinator(task: String, workingDirectory: String?) async -> ClaudeInstance {
        // 1. Create card INSTANTLY
        let agent = ClaudeInstance.create(
            name: nextName(),
            task: task,
            at: .zero
        )
        agent.agentType = .coordinator
        agent.status = .running
        agent.mainRepoPath = workingDirectory

        canvasState?.addInstance(agent)

        guard let projectPath = workingDirectory else {
            agent.status = .error
            agent.addMessage(role: .assistant, content: "No project directory")
            return agent
        }

        // Record agent creation to version history
        PersistenceService.shared.recordAction(
            agentId: agent.id,
            agentName: agent.displayName,
            action: "created",
            summary: "Started working on: \(task)",
            filesChanged: [],
            projectPath: projectPath
        )

        // 2. Setup isolated environment in background (non-blocking)
        Task.detached { [weak self] in
            await self?.setupIsolatedEnvironment(agent: agent, projectPath: projectPath, task: task)
        }

        return agent
    }

    /// Background setup - creates isolated copy and starts server
    /// Claude is started by TerminalManager when the terminal view appears
    private func setupIsolatedEnvironment(agent: ClaudeInstance, projectPath: String, task: String) async {
        print("Setting up isolated environment from: \(projectPath)")

        // Create isolated APFS clone
        let isolatedPath = await createIsolatedCopy(from: projectPath, for: agent.id)

        guard let workDir = isolatedPath else {
            print("ERROR: Failed to create isolated copy, falling back to project path")
            await MainActor.run {
                agent.workingDirectory = projectPath
                agent.addMessage(role: .assistant, content: "Using project directory (clone failed)")
            }
            return
        }

        print("Created isolated copy at: \(workDir)")

        // Verify the copy has package.json
        let packageJson = (workDir as NSString).appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: packageJson) {
            print("✓ package.json exists in isolated copy")
        } else {
            print("✗ ERROR: package.json NOT found in isolated copy!")
        }

        await MainActor.run {
            agent.workingDirectory = workDir
        }

        // Start isolated dev server for this agent (for hot reload preview)
        print("Starting server for agent in: \(workDir)")
        await ServerManager.shared.startTaskServer(for: agent.id, in: workDir)

        let port = await MainActor.run { ServerManager.shared.port(for: agent.id) }
        print("Dev server should be running on port \(port) serving from: \(workDir)")

        // Claude is started by TerminalManager when workingDirectory is set
    }

    /// Fast APFS clone (copy-on-write, nearly instant)
    /// Uses .parallel/ inside project for better file watcher compatibility
    private func createIsolatedCopy(from source: String, for instanceId: UUID) async -> String? {
        // Create .parallel directory inside the project for better file watcher support
        let parallelDir = (source as NSString).appendingPathComponent(".parallel")
        let copyPath = (parallelDir as NSString)
            .appendingPathComponent("agent-\(instanceId.uuidString.prefix(8))")

        return await withCheckedContinuation { continuation in
            Task.detached {
                let fm = FileManager.default

                // Create .parallel directory
                try? fm.createDirectory(atPath: parallelDir, withIntermediateDirectories: true)

                // Clean up existing
                try? fm.removeItem(atPath: copyPath)

                // Use rsync to copy (excludes .parallel to avoid recursion)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
                process.arguments = [
                    "-a",
                    "--exclude=.parallel",
                    "--exclude=.next",
                    "--exclude=node_modules",
                    source + "/",
                    copyPath + "/"
                ]

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        // Symlink node_modules from source for faster startup
                        let sourceNodeModules = (source as NSString).appendingPathComponent("node_modules")
                        let copyNodeModules = (copyPath as NSString).appendingPathComponent("node_modules")
                        if fm.fileExists(atPath: sourceNodeModules) {
                            try? fm.createSymbolicLink(atPath: copyNodeModules, withDestinationPath: sourceNodeModules)
                        }

                        print("Created isolated copy at \(copyPath)")
                        continuation.resume(returning: copyPath)
                        return
                    }
                } catch {
                    print("Clone failed: \(error)")
                }

                continuation.resume(returning: nil)
            }
        }
    }

    private func nextName() -> String {
        let available = names.filter { !usedNames.contains($0) }
        let name = available.randomElement() ?? "Agent-\(usedNames.count + 1)"
        usedNames.insert(name)
        return name
    }

    func resetWorkerNames() {
        usedNames.removeAll()
    }

    // MARK: - Variant Support

    /// Start a variant agent from an existing isolated copy or project
    func startVariant(_ agent: ClaudeInstance, from sourcePath: String?) async {
        guard let projectPath = sourcePath else {
            await MainActor.run {
                agent.status = .error
                agent.addMessage(role: .assistant, content: "No source directory")
            }
            return
        }

        // Setup isolated environment in background
        Task.detached { [weak self] in
            await self?.setupIsolatedEnvironment(agent: agent, projectPath: projectPath, task: agent.task)
        }
    }

    /// Start a remix by copying an existing isolated directory
    func startRemix(_ agent: ClaudeInstance, copyingFrom sourceDir: String) async {
        print("Creating remix from: \(sourceDir)")

        // Find the main project path (parent of .parallel)
        let mainProject: String
        if sourceDir.contains(".parallel") {
            let nsPath = sourceDir as NSString
            mainProject = (nsPath.deletingLastPathComponent as NSString).deletingLastPathComponent
        } else {
            mainProject = sourceDir
        }

        // Create new isolated copy from the source (which has the code changes)
        let isolatedPath = await copyIsolatedDirectory(from: sourceDir, for: agent.id, mainProject: mainProject)

        guard let workDir = isolatedPath else {
            await MainActor.run {
                agent.status = .error
                agent.addMessage(role: .assistant, content: "Failed to create remix")
            }
            return
        }

        await MainActor.run {
            agent.workingDirectory = workDir
            agent.status = .ready
            agent.addMessage(role: .assistant, content: "Remix ready - same code, new environment")

            // Record remix creation to version history
            if let projectPath = agent.mainRepoPath {
                PersistenceService.shared.recordAction(
                    agentId: agent.id,
                    agentName: agent.displayName,
                    action: "created",
                    summary: "Created remix from: \(sourceDir.components(separatedBy: "/").last ?? "agent")",
                    filesChanged: [],
                    projectPath: projectPath
                )
            }
        }

        // Start dev server for the remix
        await ServerManager.shared.startTaskServer(for: agent.id, in: workDir)

        let port = await MainActor.run { ServerManager.shared.port(for: agent.id) }
        print("Remix server starting on port \(port)")
    }

    /// Copy an existing isolated directory to create a remix
    private func copyIsolatedDirectory(from source: String, for instanceId: UUID, mainProject: String) async -> String? {
        let parallelDir = (mainProject as NSString).appendingPathComponent(".parallel")
        let copyPath = (parallelDir as NSString).appendingPathComponent("agent-\(instanceId.uuidString.prefix(8))")

        return await withCheckedContinuation { continuation in
            Task.detached {
                let fm = FileManager.default

                try? fm.createDirectory(atPath: parallelDir, withIntermediateDirectories: true)
                try? fm.removeItem(atPath: copyPath)

                // Copy the source directory (which has the code changes)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
                process.arguments = [
                    "-a",
                    "--exclude=.next",
                    "--exclude=node_modules",
                    source + "/",
                    copyPath + "/"
                ]

                do {
                    try process.run()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        // Symlink node_modules from main project
                        let mainNodeModules = (mainProject as NSString).appendingPathComponent("node_modules")
                        let copyNodeModules = (copyPath as NSString).appendingPathComponent("node_modules")
                        if fm.fileExists(atPath: mainNodeModules) {
                            try? fm.createSymbolicLink(atPath: copyNodeModules, withDestinationPath: mainNodeModules)
                        }

                        print("Created remix copy at \(copyPath)")
                        continuation.resume(returning: copyPath)
                        return
                    }
                } catch {
                    print("Remix copy failed: \(error)")
                }

                continuation.resume(returning: nil)
            }
        }
    }
}
