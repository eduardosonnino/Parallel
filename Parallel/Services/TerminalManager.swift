//
//  TerminalManager.swift
//  Parallel
//
//  Manages terminal processes independently of views
//  Processes persist even when cards are collapsed
//

import Foundation
import SwiftTerm
import AppKit

@MainActor
final class TerminalManager: ObservableObject {
    static let shared = TerminalManager()

    // MARK: - Process State

    /// Terminal views keyed by instance ID - these persist independently of SwiftUI views
    var terminals: [UUID: LocalProcessTerminalView] = [:]

    /// Track which instances have started their process
    private var startedProcesses: Set<UUID> = []

    /// Track instances waiting for user input
    @Published var waitingForInput: Set<UUID> = []

    /// Instance references for status updates
    private var instances: [UUID: ClaudeInstance] = [:]

    /// Delegate references to keep them alive
    private var delegates: [UUID: TerminalDelegate] = [:]

    /// Callbacks for process events
    var onProcessTerminated: ((UUID, Int32?) -> Void)?

    /// Track when we last notified for each instance (to avoid spam)
    private var lastNotificationTime: [UUID: Date] = [:]

    private init() {}

    // MARK: - Public API

    /// Gets or creates a terminal for an instance
    func getTerminal(for instance: ClaudeInstance) -> LocalProcessTerminalView {
        if let existing = terminals[instance.id] {
            return existing
        }

        // Create new terminal
        let terminal = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        terminal.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal.nativeForegroundColor = NSColor.white
        terminal.nativeBackgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.1, alpha: 1.0)

        terminals[instance.id] = terminal

        return terminal
    }

    /// Starts a Claude process for an instance (only starts once)
    func startProcess(for instance: ClaudeInstance) {
        // Don't start if already started
        guard !startedProcesses.contains(instance.id) else { return }

        // IMPORTANT: Don't start if working directory not set yet
        guard let workDir = instance.workingDirectory else {
            print("Waiting for working directory to be set for \(instance.name)...")
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startProcess(for: instance)
            }
            return
        }

        let terminal = getTerminal(for: instance)

        // Store instance reference for status updates
        instances[instance.id] = instance

        // Mark as started
        startedProcesses.insert(instance.id)

        // Set up delegate with output monitoring
        let delegate = TerminalDelegate(instanceId: instance.id, manager: self, instance: instance)
        terminal.processDelegate = delegate
        delegates[instance.id] = delegate  // Keep strong reference

        let task = instance.subtask ?? instance.task
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

        // Start shell
        terminal.startProcess(executable: shell, environment: nil)

        print("Starting Claude in directory: \(workDir)")

        // Change to working directory and run Claude with --dangerously-skip-permissions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            terminal.send(txt: "cd '\(workDir.replacingOccurrences(of: "'", with: "'\\''"))'\n")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                terminal.send(txt: "clear\n")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let claudePath = self.findClaudePath() {
                        let escapedTask = task.replacingOccurrences(of: "'", with: "'\\''")
                        // Use --dangerously-skip-permissions for autonomous operation
                        terminal.send(txt: "'\(claudePath)' --dangerously-skip-permissions '\(escapedTask)'\n")
                    } else {
                        terminal.send(txt: "echo '⚠️  Claude Code CLI not found.'\n")
                        terminal.send(txt: "echo 'Task: \(task.replacingOccurrences(of: "'", with: "'\\''"))'\n")
                        terminal.send(txt: "echo ''\n")
                        terminal.send(txt: "echo 'Install with: npm install -g @anthropic-ai/claude-code'\n")
                    }
                }
            }
        }

        instance.status = .running
    }

    /// Sends input to a running process
    /// If includeReturn is true, sends carriage return after the text (simulates pressing Enter)
    func sendInput(to instanceId: UUID, text: String, includeReturn: Bool = false) {
        guard let terminal = terminals[instanceId] else {
            print("No terminal found for \(instanceId)")
            return
        }

        // Send the text
        terminal.send(txt: text)

        // If requested, send carriage return (Enter key) separately
        // Using \r as that's what Enter key produces in terminal
        if includeReturn {
            // Small delay to ensure text is processed first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                terminal.send(txt: "\r")
            }
        }
    }

    /// Sends just the Enter key to the terminal
    func sendReturn(to instanceId: UUID) {
        guard let terminal = terminals[instanceId] else { return }
        terminal.send(txt: "\r")
    }

    /// Stops and removes a terminal
    func stopProcess(for instanceId: UUID) {
        if let terminal = terminals[instanceId] {
            // Terminal will be deallocated, stopping the process
            terminals.removeValue(forKey: instanceId)
        }
        startedProcesses.remove(instanceId)
        delegates.removeValue(forKey: instanceId)
    }

    /// Check if a process is running
    func isRunning(for instanceId: UUID) -> Bool {
        return startedProcesses.contains(instanceId)
    }

    // MARK: - Notification

    func notifyUserOfWaitingInput(instanceId: UUID, instanceName: String) {
        // Don't spam notifications - wait at least 10 seconds between notifications for same instance
        if let lastTime = lastNotificationTime[instanceId],
           Date().timeIntervalSince(lastTime) < 10 {
            return
        }
        lastNotificationTime[instanceId] = Date()

        // Bounce the dock icon
        NSApp.requestUserAttention(.criticalRequest)

        // Play system sound
        NSSound.beep()

        // Post a notification
        let notification = NSUserNotification()
        notification.title = "Agent needs your input"
        notification.informativeText = "\(instanceName) is waiting for a response"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Private

    private func findClaudePath() -> String? {
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
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        return nil
    }

    // MARK: - Process Delegate

    func handleProcessTerminated(instanceId: UUID, exitCode: Int32?) {
        startedProcesses.remove(instanceId)
        onProcessTerminated?(instanceId, exitCode)
    }
}

// MARK: - Terminal Delegate

private class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate {
    let instanceId: UUID
    weak var manager: TerminalManager?
    weak var instance: ClaudeInstance?
    private var checkTimer: Timer?
    private var lastContent: String = ""

    // Patterns that indicate Claude is asking a question
    private let questionPatterns = [
        // Yes/No prompts
        "? (y/n)",
        "? [y/n]",
        "? (Y/n)",
        "? [Y/n]",
        "(yes/no)",
        // Claude Code specific patterns - these are the most important
        "Do you want to",
        "Esc to cancel",
        "Tab to amend",
        "> 1.",           // Selected option indicator
        "❯ 1.",           // Alternative arrow
        "› 1.",           // Another arrow variant
        "1. Yes",
        "2. Yes,",
        "3. No",
        "allow all edits",
        "allow this edit",
        "make this edit",
        // Question marks at end of lines (common pattern)
        "globals.css?",
        "this file?",
        "these files?",
        "this change?",
        "these changes?",
        "proceed?",
        "continue?",
        // Common question patterns
        "Press Enter",
        "press enter",
        "Continue?",
        "Proceed?",
        "Would you like",
        "Should I",
        "Please choose",
        "Select an option",
        "Enter your",
        "Type your",
        "Overwrite?",
        "Replace?",
        "Delete?",
        "Create?",
        // Permission prompts
        "Allow?",
        "Confirm?",
        "Accept?"
    ]

    init(instanceId: UUID, manager: TerminalManager, instance: ClaudeInstance) {
        self.instanceId = instanceId
        self.manager = manager
        self.instance = instance
        super.init()

        // Start monitoring on main thread
        DispatchQueue.main.async { [weak self] in
            self?.startQuestionMonitoring()
        }
    }

    deinit {
        checkTimer?.invalidate()
    }

    private func startQuestionMonitoring() {
        // Invalidate existing timer if any
        checkTimer?.invalidate()

        // Check every 0.3 seconds for question patterns (more frequent)
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkForQuestionPatterns()
        }

        // Make sure timer runs even when UI is tracking
        if let timer = checkTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        checkTimer?.invalidate()
        Task { @MainActor in
            manager?.handleProcessTerminated(instanceId: instanceId, exitCode: exitCode)
            manager?.waitingForInput.remove(instanceId)
            instance?.status = (exitCode ?? 1) == 0 ? .completed : .error
        }
    }

    private func checkForQuestionPatterns() {
        Task { @MainActor in
            guard let manager = manager else { return }
            guard let terminal = manager.terminals[instanceId] else { return }
            guard let instance = instance else { return }

            // Get terminal content
            let data = terminal.getTerminal().getBufferAsData()
            guard let terminalContent = String(data: data, encoding: .utf8) else { return }

            // Check last portion of content
            let recentContent = String(terminalContent.suffix(3000))

            // Skip if content hasn't changed
            if recentContent == lastContent {
                return
            }
            lastContent = recentContent

            // Check for question patterns
            var foundPattern: String? = nil
            for pattern in questionPatterns {
                if recentContent.localizedCaseInsensitiveContains(pattern) {
                    foundPattern = pattern
                    break
                }
            }

            let hasQuestion = foundPattern != nil

            if hasQuestion {
                if instance.status != .waiting {
                    print("🔔 Question detected for \(instance.name): '\(foundPattern ?? "unknown")'")
                    manager.waitingForInput.insert(instanceId)
                    instance.status = .waiting

                    // Notify user
                    manager.notifyUserOfWaitingInput(instanceId: instanceId, instanceName: instance.name)
                }
            } else if instance.status == .waiting {
                // If no question pattern found and we were waiting, go back to running
                print("✅ Question resolved for \(instance.name)")
                manager.waitingForInput.remove(instanceId)
                instance.status = .running
            }
        }
    }
}
