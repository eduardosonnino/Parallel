//
//  ServerManager.swift
//  Parallel
//
//  Simple dev server management - non-blocking
//

import Foundation

@MainActor
@Observable
final class ServerManager {
    static let shared = ServerManager()

    private let mainPort: Int = 3000
    private let taskPortRange = 3001...3099

    private(set) var assignedPorts: [UUID: Int] = [:]
    private(set) var worktreePaths: [UUID: String] = [:]
    private var runningProcesses: [UUID: Process] = [:]
    private(set) var mainServerId: UUID = UUID()

    var mainServerPort: Int { mainPort }

    private init() {}

    // MARK: - Port Management

    func port(for instanceId: UUID) -> Int {
        if instanceId == mainServerId { return mainPort }
        if let existing = assignedPorts[instanceId] { return existing }

        // Assign next available port
        let usedPorts = Set(assignedPorts.values)
        for port in taskPortRange {
            if !usedPorts.contains(port) {
                assignedPorts[instanceId] = port
                return port
            }
        }
        return taskPortRange.lowerBound
    }

    func releasePort(for instanceId: UUID) {
        assignedPorts.removeValue(forKey: instanceId)
        stopServer(for: instanceId)
        worktreePaths.removeValue(forKey: instanceId)
    }

    func workingDirectory(for instanceId: UUID) -> String? {
        worktreePaths[instanceId]
    }

    // MARK: - Server Management

    func startMainServer(in workingDirectory: String) async {
        // Check if already running
        if runningProcesses[mainServerId]?.isRunning == true { return }

        await startServer(for: mainServerId, in: workingDirectory, port: mainPort)
    }

    func startTaskServer(for instanceId: UUID, in workingDirectory: String) async {
        let port = port(for: instanceId)
        print("🚀 Starting task server for \(instanceId.uuidString.prefix(8)) on port \(port)")
        print("   Directory: \(workingDirectory)")

        // Kill any existing process on this port using lsof
        let killScript = "lsof -ti :\(port) | xargs kill -9 2>/dev/null || true"
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
        killProcess.arguments = ["-c", killScript]
        try? killProcess.run()
        killProcess.waitUntilExit()

        // Small delay to ensure port is freed
        try? await Task.sleep(for: .milliseconds(500))

        worktreePaths[instanceId] = workingDirectory
        await startServer(for: instanceId, in: workingDirectory, port: port)
    }

    private func startServer(for instanceId: UUID, in workingDirectory: String, port: Int) async {
        stopServer(for: instanceId)

        let packageJsonPath = (workingDirectory as NSString).appendingPathComponent("package.json")

        guard FileManager.default.fileExists(atPath: packageJsonPath) else {
            print("❌ No package.json found in \(workingDirectory)")
            // List directory contents for debugging
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: workingDirectory) {
                print("   Directory contents: \(contents.prefix(10))")
            }
            return
        }

        guard let command = buildDevCommand(packageJsonPath: packageJsonPath, workingDirectory: workingDirectory, port: port) else {
            print("❌ Could not build dev command - no dev/start/serve script in package.json")
            return
        }

        print("Starting dev server: \(command) in \(workingDirectory)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        var env = ProcessInfo.processInfo.environment
        env["PORT"] = String(port)
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env

        // Log server output for debugging
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                print("[Server:\(port)] \(output)")
            }
        }

        do {
            try process.run()
            runningProcesses[instanceId] = process
            print("Started dev server on port \(port) in \(workingDirectory)")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    private func buildDevCommand(packageJsonPath: String, workingDirectory: String, port: Int) -> String? {
        guard let data = FileManager.default.contents(atPath: packageJsonPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = json["scripts"] as? [String: Any] else {
            return nil
        }

        let pm = detectPackageManager(in: workingDirectory)

        for script in ["dev", "start", "serve"] {
            if let scriptCmd = scripts[script] as? String {
                // Enable polling for file watching (needed for temp directories)
                // CHOKIDAR_USEPOLLING works for most Node.js file watchers
                var envPrefix = "PORT=\(port) CHOKIDAR_USEPOLLING=true WATCHPACK_POLLING=true "

                // Add framework-specific polling flags
                if scriptCmd.contains("next") {
                    // Next.js uses watchpack
                    envPrefix += "WATCHPACK_POLLING=true "
                } else if scriptCmd.contains("vite") {
                    // Vite has its own polling option
                    return "\(envPrefix)\(pm) run \(script) -- --port \(port) --host"
                }

                return "\(envPrefix)\(pm) run \(script)"
            }
        }
        return nil
    }

    private func detectPackageManager(in dir: String) -> String {
        let fm = FileManager.default
        if fm.fileExists(atPath: (dir as NSString).appendingPathComponent("pnpm-lock.yaml")) { return "pnpm" }
        if fm.fileExists(atPath: (dir as NSString).appendingPathComponent("yarn.lock")) { return "yarn" }
        if fm.fileExists(atPath: (dir as NSString).appendingPathComponent("bun.lockb")) { return "bun" }
        return "npm"
    }

    func stopServer(for instanceId: UUID) {
        runningProcesses[instanceId]?.terminate()
        runningProcesses.removeValue(forKey: instanceId)
    }

    func stopAllServers() {
        for id in runningProcesses.keys {
            stopServer(for: id)
        }
    }

    func isServerRunning(for instanceId: UUID) -> Bool {
        runningProcesses[instanceId]?.isRunning ?? false
    }

    func previewURL(for instanceId: UUID) -> URL? {
        let port = instanceId == mainServerId ? mainPort : (assignedPorts[instanceId] ?? mainPort)
        return URL(string: "http://localhost:\(port)")
    }
}
