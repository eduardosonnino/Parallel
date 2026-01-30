import SwiftUI

struct TerminalView: View {
    let output: String
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Terminal toolbar
            HStack {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Toggle(isOn: $autoScroll) {
                    Text("Auto-scroll")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(output, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy Output")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Terminal content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(output.isEmpty ? "Waiting for output..." : output)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(output.isEmpty ? .secondary : terminalTextColor)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .id("bottom")
                    }
                }
                .background(terminalBackgroundColor)
                .onChange(of: output) { _, _ in
                    if autoScroll {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var terminalBackgroundColor: Color {
        Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0))
    }

    private var terminalTextColor: Color {
        Color(nsColor: NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
    }
}

struct AnsiText: View {
    let text: String

    var body: some View {
        Text(parseAnsi(text))
            .font(.system(.body, design: .monospaced))
    }

    private func parseAnsi(_ input: String) -> AttributedString {
        var result = AttributedString(input.replacingOccurrences(
            of: "\u{001B}\\[[0-9;]*m",
            with: "",
            options: .regularExpression
        ))
        return result
    }
}

struct CommandInput: View {
    @Binding var command: String
    let onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("$")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            TextField("Enter command...", text: $command)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .onSubmit {
                    if !command.isEmpty {
                        onSubmit(command)
                        command = ""
                    }
                }
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

#Preview {
    TerminalView(output: """
    $ claude --print "Add authentication"

    I'll help you add authentication to your project.

    First, let me analyze the codebase structure...

    Found the following relevant files:
    - src/app.swift
    - src/models/user.swift
    - src/routes/auth.swift

    Creating authentication module...

    [INFO] Writing src/auth/authenticator.swift
    [INFO] Writing src/auth/token.swift
    [INFO] Modifying src/app.swift

    Done! Authentication has been added.
    """)
    .frame(width: 600, height: 400)
}
