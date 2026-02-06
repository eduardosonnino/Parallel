//
//  ClaudeCodeRunner.swift
//  Parallel
//
//  Service to run Claude Code CLI processes
//

import Foundation

@MainActor
final class ClaudeCodeRunner: ObservableObject {
    static let shared = ClaudeCodeRunner()

    // MARK: - Process Management

    private var runningProcesses: [UUID: Process] = [:]
    private var inputPipes: [UUID: Pipe] = [:]
    private var outputBuffers: [UUID: String] = [:]

    // MARK: - Callbacks

    /// Called when Claude asks a question (detected from output)
    var onQuestionDetected: ((UUID, String) -> Void)?

    /// Called when output is received
    var onOutput: ((UUID, String) -> Void)?

    /// Called when a process completes
    var onProcessCompleted: ((UUID, Int32) -> Void)?

    private init() {}

    // MARK: - Project Trust

    /// Track directories we've initialized for this session
    private var trustedDirectories: Set<String> = []

    func trustDirectory(_ directory: String) async {
        // Skip if already trusted this session
        guard !trustedDirectories.contains(directory) else { return }
        trustedDirectories.insert(directory)
        print("Registered directory: \(directory)")
    }

    // MARK: - Public Methods

    /// Starts a Claude Code process for an instance
    func startClaude(
        for instance: ClaudeInstance,
        prompt: String,
        workingDirectory: String? = nil,
        systemPrompt: String? = nil,
        oneShot: Bool = false
    ) async throws {
        let instanceId = instance.id

        // Find Claude Code executable
        guard let claudePath = findClaudePath() else {
            throw ClaudeRunnerError.claudeNotFound
        }

        // Get working directory - REQUIRED
        let workDir = workingDirectory ?? instance.workingDirectory
        guard let dir = workDir else {
            print("ERROR: No working directory set for Claude!")
            throw ClaudeRunnerError.processNotRunning
        }

        print("Claude starting in directory: \(dir)")

        // Use shell to cd into directory first, then run claude
        // This ensures Claude Code uses the correct workspace
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        // Escape the prompt for shell
        let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\\''")

        // Build the claude command
        var claudeArgs = "--dangerously-skip-permissions"
        if oneShot {
            claudeArgs += " --print"
        }
        if let systemPrompt = systemPrompt {
            let escapedSystem = systemPrompt.replacingOccurrences(of: "'", with: "'\\''")
            claudeArgs += " --system-prompt '\(escapedSystem)'"
        }
        claudeArgs += " -p '\(escapedPrompt)'"

        // cd into directory, then run claude
        let shellCommand = "cd '\(dir)' && '\(claudePath)' \(claudeArgs)"
        process.arguments = ["-c", shellCommand]

        // Environment - ensure Claude has access to PATH for tools
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        process.environment = env

        // Setup pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        // Store references
        runningProcesses[instanceId] = process
        inputPipes[instanceId] = inputPipe
        outputBuffers[instanceId] = ""

        // Setup output handlers
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.handleOutput(output, for: instanceId)
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.handleOutput(output, for: instanceId, isError: true)
            }
        }

        // Setup termination handler
        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.handleTermination(for: instanceId, exitCode: proc.terminationStatus)
            }
        }

        // Start the process
        try process.run()
    }

    /// Sends input to a running Claude process
    func sendInput(to instanceId: UUID, input: String) {
        guard let inputPipe = inputPipes[instanceId] else { return }

        let inputWithNewline = input + "\n"
        if let data = inputWithNewline.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
        }
    }

    /// Stops a running Claude process
    func stopClaude(for instanceId: UUID) {
        guard let process = runningProcesses[instanceId] else { return }

        process.terminate()
        cleanup(for: instanceId)
    }

    /// Checks if a process is running
    func isRunning(for instanceId: UUID) -> Bool {
        guard let process = runningProcesses[instanceId] else { return false }
        return process.isRunning
    }

    // MARK: - Private Methods

    private func handleOutput(_ output: String, for instanceId: UUID, isError: Bool = false) {
        // Append to buffer
        outputBuffers[instanceId, default: ""] += output

        // Notify callback
        onOutput?(instanceId, output)

        // Check for question patterns
        if detectQuestion(in: output) {
            onQuestionDetected?(instanceId, output)
        }
    }

    private func handleTermination(for instanceId: UUID, exitCode: Int32) {
        cleanup(for: instanceId)
        onProcessCompleted?(instanceId, exitCode)
    }

    private func cleanup(for instanceId: UUID) {
        // Close pipes
        if let inputPipe = inputPipes[instanceId] {
            try? inputPipe.fileHandleForWriting.close()
        }

        // Remove references
        runningProcesses.removeValue(forKey: instanceId)
        inputPipes.removeValue(forKey: instanceId)
        outputBuffers.removeValue(forKey: instanceId)
    }

    func findClaudePath() -> String? {
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            NSHomeDirectory() + "/.local/bin/claude",
            "/usr/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try using which
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try? whichProcess.run()
        whichProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        return nil
    }

    private func detectQuestion(in output: String) -> Bool {
        // Patterns that indicate Claude is asking a question
        let questionPatterns = [
            "?",
            "Would you like",
            "Should I",
            "Do you want",
            "Please choose",
            "Select an option",
            "[Y/n]",
            "[y/N]",
            "(yes/no)"
        ]

        let lowercased = output.lowercased()
        return questionPatterns.contains { pattern in
            lowercased.contains(pattern.lowercased())
        }
    }

    /// Gets the accumulated output for an instance
    func getOutput(for instanceId: UUID) -> String {
        return outputBuffers[instanceId] ?? ""
    }
}

// MARK: - Errors

enum ClaudeRunnerError: Error, LocalizedError {
    case claudeNotFound
    case processAlreadyRunning
    case processNotRunning

    var errorDescription: String? {
        switch self {
        case .claudeNotFound:
            return "Claude Code CLI not found. Please install it first."
        case .processAlreadyRunning:
            return "A Claude process is already running for this instance."
        case .processNotRunning:
            return "No Claude process is running for this instance."
        }
    }
}
