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
            HStack(alignment: .top, spacing: 12) {
                // Status indicator with ring
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    if instance.status == .running {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(statusColor, lineWidth: 2)
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))
                            .animation(
                                .linear(duration: 1.0).repeatForever(autoreverses: false),
                                value: instance.status
                            )
                    }

                    Image(systemName: statusIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(instance.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        if instance.isolationMode == .worktree {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green.opacity(0.8))
                                .help("Isolated worktree")
                        }

                        if instance.isMerged {
                            Text("Merged")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(instance.branchName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                InstanceMenu(instance: instance)
            }
            .padding(14)

            // Task description
            Text(instance.task)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            // Action button for completed worktree instances
            if instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged {
                Button {
                    Task {
                        await appState.mergeAndBuild(instance)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 10))
                        Text("Merge & Build")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }

            // Footer
            HStack(spacing: 14) {
                StatItem(icon: "doc.text", value: instance.changedFiles.count, label: "files")
                StatItem(icon: "arrow.triangle.branch", value: instance.commits.count, label: "commits")

                Spacer()

                Text(instance.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
        .frame(height: showMergeButton ? 200 : 165)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .shadow(
            color: .black.opacity(isHovered ? 0.1 : 0.04),
            radius: isHovered ? 8 : 4,
            y: isHovered ? 4 : 2
        )
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var showMergeButton: Bool {
        instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged
    }

    private var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return .accentColor
        } else if instance.isMerged {
            return .green.opacity(0.4)
        } else if isHovered {
            return Color(nsColor: .separatorColor).opacity(0.8)
        }
        return Color.clear
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }

    private var statusColor: Color {
        switch instance.status {
        case .idle: return .secondary
        case .starting: return .yellow
        case .running: return .blue
        case .ready: return .green
        case .completed: return .green
        case .error: return .red
        case .stopped: return .secondary
        }
    }

    private var statusIcon: String {
        switch instance.status {
        case .idle: return "circle"
        case .starting: return "arrow.clockwise"
        case .running: return "terminal"
        case .ready: return "checkmark"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .stopped: return "stop.fill"
        }
    }
}

struct InstanceMenu: View {
    let instance: ClaudeInstance
    @EnvironmentObject var appState: AppState

    var body: some View {
        Menu {
            Button {
                appState.selectedInstanceId = instance.id
            } label: {
                Label("View Output", systemImage: "terminal")
            }

            Divider()

            if instance.status.isActive {
                Button {
                    appState.stopInstance(instance)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    Task {
                        await appState.instanceManager.restartInstance(
                            instance,
                            gitManager: appState.gitManager
                        )
                    }
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
            }

            Button {
                appState.instanceManager.markInstanceReady(instance)
            } label: {
                Label("Mark Ready", systemImage: "checkmark.circle")
            }
            .disabled(instance.status != .running)

            if instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged {
                Divider()

                Button {
                    Task {
                        await appState.mergeInstance(instance)
                    }
                } label: {
                    Label("Merge to Main", systemImage: "arrow.triangle.merge")
                }

                Button {
                    Task {
                        await appState.mergeAndBuild(instance)
                    }
                } label: {
                    Label("Merge & Build", systemImage: "hammer")
                }
            }

            Divider()

            Button(role: .destructive) {
                Task {
                    await appState.cleanupInstance(instance)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.08))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct StatItem: View {
    let icon: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)

            Text("\(value)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(value > 0 ? .primary : .secondary)
        }
        .help("\(value) \(label)")
    }
}

#Preview {
    VStack(spacing: 16) {
        InstanceCardView(
            instance: ClaudeInstance(
                name: "Feature Auth",
                task: "Implement user authentication with OAuth2 support and session management",
                projectPath: URL(fileURLWithPath: "/Users/test/project"),
                branchName: "claude/feature-auth-abc123",
                isolationMode: .worktree,
                status: .completed
            )
        )

        InstanceCardView(
            instance: ClaudeInstance(
                name: "Bug Fix",
                task: "Fix login redirect issue when user session expires",
                projectPath: URL(fileURLWithPath: "/Users/test/project"),
                branchName: "claude/bug-fix-xyz789",
                isolationMode: .worktree,
                status: .running
            )
        )

        InstanceCardView(
            instance: ClaudeInstance(
                name: "API Refactor",
                task: "Refactor REST API endpoints to use async/await",
                projectPath: URL(fileURLWithPath: "/Users/test/project"),
                branchName: "claude/refactor-api-def456",
                isolationMode: .worktree,
                status: .ready
            )
        )
    }
    .environmentObject(AppState())
    .frame(width: 340)
    .padding(20)
    .background(Color(nsColor: .windowBackgroundColor))
}
