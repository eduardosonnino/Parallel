import SwiftUI

struct BuildControlView: View {
    @EnvironmentObject var appState: AppState
    @State private var customBuildCommand: String = ""
    @State private var showOutput = true

    var body: some View {
        VStack(spacing: 0) {
            // Build status header
            buildStatusHeader

            Divider()

            HSplitView {
                // Left panel - Build controls
                buildControls
                    .frame(minWidth: 300, maxWidth: 400)

                // Right panel - Build output
                buildOutputPanel
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let project = appState.currentProject {
                customBuildCommand = project.buildCommand
            }
        }
    }

    private var buildStatusHeader: some View {
        HStack(spacing: 16) {
            // Status indicator
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 40, height: 40)

                    if appState.isRunningBuild {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: statusIcon)
                            .font(.system(size: 18))
                            .foregroundColor(statusColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)

                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Instance readiness
            HStack(spacing: 8) {
                ForEach(appState.instances) { instance in
                    InstanceStatusDot(instance: instance)
                }
            }

            Spacer()

            // Build button
            Button {
                Task {
                    await appState.runBuildIfAllReady()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: appState.isRunningBuild ? "stop.fill" : "play.fill")
                    Text(appState.isRunningBuild ? "Stop" : "Build")
                }
                .frame(width: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.allInstancesReady ? .green : .blue)
            .disabled(!appState.allInstancesReady && !appState.isRunningBuild)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var statusColor: Color {
        if appState.isRunningBuild {
            return .blue
        } else if appState.allInstancesReady {
            return .green
        } else {
            return .orange
        }
    }

    private var statusIcon: String {
        if appState.allInstancesReady {
            return "checkmark"
        } else {
            return "clock"
        }
    }

    private var statusTitle: String {
        if appState.isRunningBuild {
            return "Building..."
        } else if appState.allInstancesReady {
            return "Ready to Build"
        } else {
            return "Waiting for Instances"
        }
    }

    private var statusSubtitle: String {
        if appState.isRunningBuild {
            return "Build in progress"
        } else {
            return "\(appState.readyInstancesCount)/\(appState.instances.count) instances ready"
        }
    }

    private var buildControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Build command section
            VStack(alignment: .leading, spacing: 12) {
                Text("Build Command")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    TextField("Build command", text: $customBuildCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button {
                        // Reset to detected
                        if let project = appState.currentProject {
                            customBuildCommand = project.buildCommand
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to detected command")
                }
            }
            .padding(16)

            Divider()

            // Instances overview
            VStack(alignment: .leading, spacing: 12) {
                Text("Instances")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if appState.instances.isEmpty {
                    Text("No instances running")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appState.instances) { instance in
                        InstanceBuildRow(instance: instance)
                    }
                }
            }
            .padding(16)

            Divider()

            // Build options
            VStack(alignment: .leading, spacing: 12) {
                Text("Options")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Toggle("Auto-build when all ready", isOn: .constant(false))
                    .font(.subheadline)

                Toggle("Run tests after build", isOn: .constant(false))
                    .font(.subheadline)

                Toggle("Show notifications", isOn: .constant(true))
                    .font(.subheadline)
            }
            .padding(16)

            Spacer()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var buildOutputPanel: some View {
        VStack(spacing: 0) {
            // Output header
            HStack {
                Text("Build Output")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.buildOutput, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(appState.buildOutput.isEmpty)

                Button {
                    appState.buildOutput = ""
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(appState.buildOutput.isEmpty)
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Output content
            ScrollView {
                if appState.buildOutput.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "terminal")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)

                        Text("No build output")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                } else {
                    Text(appState.buildOutput)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Color(nsColor: NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            .background(Color(nsColor: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)))
        }
    }
}

struct InstanceStatusDot: View {
    let instance: ClaudeInstance

    var body: some View {
        VStack(spacing: 4) {
            StatusIndicator(status: instance.status)
            Text(instance.name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 60)
        .help("\(instance.name): \(instance.status.rawValue)")
    }
}

struct InstanceBuildRow: View {
    let instance: ClaudeInstance

    var body: some View {
        HStack(spacing: 12) {
            StatusIndicator(status: instance.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.subheadline)

                Text(instance.branchName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(instance.status.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BuildControlView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
