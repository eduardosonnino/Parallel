//
//  TerminalView.swift
//  Parallel
//
//  SwiftTerm-based terminal view that connects to TerminalManager
//  The process lifecycle is managed by TerminalManager, not by this view
//

import SwiftUI
import SwiftTerm

// MARK: - Claude Terminal View (connects to existing process)

struct ClaudeTerminalView: View {
    let instance: ClaudeInstance

    var body: some View {
        VStack(spacing: 0) {
            // Terminal header
            HStack {
                Circle()
                    .fill(TerminalManager.shared.isRunning(for: instance.id) ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text("Terminal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if TerminalManager.shared.isRunning(for: instance.id) {
                    Text("Running...")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.3))

            // Terminal content - connects to existing process
            ManagedTerminalView(instance: instance)
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Managed Terminal View (uses TerminalManager)

struct ManagedTerminalView: NSViewRepresentable {
    let instance: ClaudeInstance

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(red: 0.08, green: 0.09, blue: 0.1, alpha: 1.0).cgColor

        // Get the terminal from the manager (creates if needed)
        let terminal = TerminalManager.shared.getTerminal(for: instance)
        terminal.frame = container.bounds
        terminal.autoresizingMask = [.width, .height]

        // Remove from previous superview if any (in case of view recreation)
        terminal.removeFromSuperview()
        container.addSubview(terminal)

        // Start the process if not already started (needs to be in view hierarchy)
        DispatchQueue.main.async {
            TerminalManager.shared.startProcess(for: self.instance)
        }

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Ensure terminal fills container
        let terminal = TerminalManager.shared.getTerminal(for: instance)
        if terminal.superview != nsView {
            terminal.removeFromSuperview()
            nsView.addSubview(terminal)
        }
        terminal.frame = nsView.bounds
    }
}

// MARK: - Compact Terminal View (for card)

struct CompactTerminalView: View {
    let instance: ClaudeInstance

    @State private var terminalHeight: CGFloat = 200

    private var isRunning: Bool {
        TerminalManager.shared.isRunning(for: instance.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)

                    Text("TERMINAL")
                        .font(.system(size: 9, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))

            // Terminal - connects to existing process managed by TerminalManager
            ManagedTerminalView(instance: instance)
                .frame(height: terminalHeight)
        }
        .background(Color(red: 0.06, green: 0.07, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
