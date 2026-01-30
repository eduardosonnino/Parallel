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

                        // Isolation mode badge
                        if instance.isolationMode == .worktree {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                                .help("Isolated worktree - safe to build")
                        }

                        // Merged badge
                        if instance.isMerged {
                            Text("Merged")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
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

                    // Merge options for completed worktree instances
                    if instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged {
                        Button("Merge to Main") {
                            Task {
                                await appState.mergeInstance(instance)
                            }
                        }

                        Button("Merge & Build") {
                            Task {
                                await appState.mergeAndBuild(instance)
                            }
                        }

                        Divider()
                    }

                    Button("Remove", role: .destructive) {
                        Task {
                            await appState.cleanupInstance(instance)
                        }
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

            // Merge button for completed instances
            if instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged {
                HStack {
                    Button {
                        Task {
                            await appState.mergeAndBuild(instance)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.merge")
                            Text("Merge & Build")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

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

                if instance.isolationMode == .worktree {
                    Image(systemName: "lock.shield")
                        .font(.caption)
                        .foregroundColor(.green)
                        .help("Isolated")
                }

                Spacer()

                Text(instance.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(height: instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged ? 220 : 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : (instance.isMerged ? Color.green.opacity(0.5) : Color(nsColor: .separatorColor)),
                    lineWidth: isSelected ? 2 : (instance.isMerged ? 1 : 0.5)
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
    VStack {
        InstanceCardView(
            instance: ClaudeInstance(
                name: "Feature Auth",
                task: "Implement user authentication with OAuth2 support",
                projectPath: URL(fileURLWithPath: "/Users/test/project"),
                branchName: "claude/feature-auth-abc123",
                isolationMode: .worktree,
                status: .completed
            )
        )

        InstanceCardView(
            instance: ClaudeInstance(
                name: "Bug Fix",
                task: "Fix login redirect issue",
                projectPath: URL(fileURLWithPath: "/Users/test/project"),
                branchName: "claude/bug-fix-xyz789",
                isolationMode: .worktree,
                status: .running
            )
        )
    }
    .environmentObject(AppState())
    .frame(width: 350)
    .padding()
}
