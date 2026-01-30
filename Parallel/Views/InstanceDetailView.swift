import SwiftUI

struct InstanceDetailView: View {
    let instance: ClaudeInstance
    @EnvironmentObject var appState: AppState
    @State private var selectedDetailTab: DetailTab = .output

    enum DetailTab: String, CaseIterable {
        case output = "Output"
        case changes = "Changes"
        case commits = "Commits"

        var icon: String {
            switch self {
            case .output: return "terminal"
            case .changes: return "doc.text"
            case .commits: return "clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Instance header
            instanceHeader

            Divider()

            // Tab bar
            tabBar

            Divider()

            // Content
            tabContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var instanceHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    StatusIndicator(status: instance.status, size: .large)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(instance.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(instance.branchName)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Text(instance.task)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(instance.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBackgroundColor)
                    .foregroundColor(statusForegroundColor)
                    .clipShape(Capsule())

                Text(instance.formattedDuration)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }

    private var statusBackgroundColor: Color {
        switch instance.status {
        case .ready, .completed: return Color.green.opacity(0.15)
        case .running: return Color.blue.opacity(0.15)
        case .error: return Color.red.opacity(0.15)
        case .stopped: return Color.orange.opacity(0.15)
        default: return Color.secondary.opacity(0.15)
        }
    }

    private var statusForegroundColor: Color {
        switch instance.status {
        case .ready, .completed: return Color.green
        case .running: return Color.blue
        case .error: return Color.red
        case .stopped: return Color.orange
        default: return Color.secondary
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDetailTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.rawValue)
                            .font(.subheadline)

                        if tab == .changes && !instance.changedFiles.isEmpty {
                            Text("\(instance.changedFiles.count)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedDetailTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedDetailTab == tab ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if instance.status.isActive {
                    Button {
                        appState.stopInstance(instance)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Stop Instance")
                }

                Button {
                    Task {
                        await appState.instanceManager.refreshInstanceGitStatus(
                            instance,
                            gitManager: appState.gitManager
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.trailing, 16)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedDetailTab {
        case .output:
            TerminalView(output: instance.output)
        case .changes:
            changesContent
        case .commits:
            commitsContent
        }
    }

    private var changesContent: some View {
        List {
            if instance.changedFiles.isEmpty {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text("No file changes detected")
                )
            } else {
                ForEach(instance.changedFiles) { change in
                    FileChangeRow(change: change)
                }
            }
        }
        .listStyle(.inset)
    }

    private var commitsContent: some View {
        List {
            if instance.commits.isEmpty {
                ContentUnavailableView(
                    "No Commits",
                    systemImage: "clock",
                    description: Text("No commits on this branch yet")
                )
            } else {
                ForEach(instance.commits) { commit in
                    CommitRow(commit: commit)
                }
            }
        }
        .listStyle(.inset)
    }
}

struct FileChangeRow: View {
    let change: GitChange

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: change.changeType.iconName)
                .foregroundColor(changeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.fileName)
                    .font(.system(.body, design: .monospaced))

                Text(change.directory)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !change.stats.isEmpty {
                Text(change.stats)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var changeColor: Color {
        switch change.changeType {
        case .added: return .green
        case .modified: return .orange
        case .deleted: return .red
        case .renamed: return .blue
        default: return .secondary
        }
    }
}

struct CommitRow: View {
    let commit: GitCommit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(commit.shortId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(commit.author)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(commit.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    InstanceDetailView(
        instance: ClaudeInstance(
            name: "Feature Auth",
            task: "Implement user authentication with OAuth2 support",
            projectPath: URL(fileURLWithPath: "/Users/test/project"),
            branchName: "claude/feature-auth-abc123",
            status: .running,
            output: "Working on authentication...\nCreating auth module...",
            changedFiles: [
                GitChange(filePath: "src/auth/login.swift", changeType: .added),
                GitChange(filePath: "src/models/user.swift", changeType: .modified)
            ]
        )
    )
    .environmentObject(AppState())
    .frame(width: 600, height: 500)
}
