import SwiftUI

struct InstanceCardView: View {
    let instance: ClaudeInstance
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    private var isSelected: Bool {
        appState.selectedInstanceId == instance.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        StatusIndicator(status: instance.status)
                        Text(instance.name)
                            .font(.system(.headline, design: .default))
                            .foregroundColor(.primary)
                    }

                    Text(instance.branchName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button("View Output") {
                        appState.selectedInstanceId = instance.id
                    }

                    Divider()

                    if instance.status.isActive {
                        Button("Stop") {
                            appState.stopInstance(instance)
                        }
                    } else {
                        Button("Restart") {
                            Task {
                                await appState.instanceManager.restartInstance(
                                    instance,
                                    gitManager: appState.gitManager
                                )
                            }
                        }
                    }

                    Button("Mark Ready") {
                        appState.instanceManager.markInstanceReady(instance)
                    }
                    .disabled(instance.status != .running)

                    Divider()

                    Button("Remove", role: .destructive) {
                        appState.instanceManager.removeInstance(instance)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(16)

            Divider()
                .opacity(0.5)

            // Task description
            Text(instance.task)
                .font(.system(.subheadline))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(16)

            Spacer(minLength: 0)

            Divider()
                .opacity(0.5)

            // Footer stats
            HStack(spacing: 16) {
                Label("\(instance.changedFiles.count)", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Label("\(instance.commits.count)", systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(instance.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 8 : 4, y: 2)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    InstanceCardView(
        instance: ClaudeInstance(
            name: "Feature Auth",
            task: "Implement user authentication with OAuth2 support",
            projectPath: URL(fileURLWithPath: "/Users/test/project"),
            branchName: "claude/feature-auth-abc123",
            status: .running
        )
    )
    .environmentObject(AppState())
    .frame(width: 350)
    .padding()
}
