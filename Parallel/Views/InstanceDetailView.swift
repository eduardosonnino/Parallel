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
            case .commits: return "clock.arrow.circlepath"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            instanceHeader
            Divider()
            tabBar
            Divider()
            tabContent
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var instanceHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                if instance.status == .running {
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(statusColor, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(instance.name)
                        .font(.system(size: 15, weight: .semibold))

                    if instance.isolationMode == .worktree {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green.opacity(0.8))
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

                Text(instance.task)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(instance.status.rawValue.capitalized)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())

                Text(instance.formattedDuration)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedDetailTab == tab,
                    badge: badgeCount(for: tab)
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDetailTab = tab
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 6) {
                if instance.status.isActive {
                    ActionButton(icon: "stop.fill", color: .red) {
                        appState.stopInstance(instance)
                    }
                    .help("Stop Instance")
                }

                ActionButton(icon: "arrow.clockwise", color: .secondary) {
                    Task {
                        await appState.instanceManager.refreshInstanceGitStatus(
                            instance,
                            gitManager: appState.gitManager
                        )
                    }
                }
                .help("Refresh")

                if instance.isolationMode == .worktree && instance.status == .completed && !instance.isMerged {
                    Button {
                        Task {
                            await appState.mergeAndBuild(instance)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 10))
                            Text("Merge")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                }
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func badgeCount(for tab: DetailTab) -> Int? {
        switch tab {
        case .output: return nil
        case .changes:
            let count = instance.changedFiles.count
            return count > 0 ? count : nil
        case .commits:
            let count = instance.commits.count
            return count > 0 ? count : nil
        }
    }

    // MARK: - Tab Content

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
        Group {
            if instance.changedFiles.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Changes",
                    message: "No file changes detected yet"
                )
            } else {
                List {
                    ForEach(instance.changedFiles) { change in
                        FileChangeRow(change: change)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private var commitsContent: some View {
        Group {
            if instance.commits.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Commits",
                    message: "No commits on this branch yet"
                )
            } else {
                List {
                    ForEach(instance.commits) { commit in
                        CommitRow(commit: commit)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Helpers

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

// MARK: - Supporting Views

struct TabButton: View {
    let tab: InstanceDetailView.DetailTab
    let isSelected: Bool
    let badge: Int?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))

                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) :
                (isHovered ? Color.secondary.opacity(0.08) : Color.clear)
            )
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 26, height: 26)
                .background(isHovered ? color.opacity(0.1) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FileChangeRow: View {
    let change: GitChange

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: change.changeType.iconName)
                .font(.system(size: 11))
                .foregroundColor(changeColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.fileName)
                    .font(.system(size: 11, design: .monospaced))

                Text(change.directory)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !change.stats.isEmpty {
                Text(change.stats)
                    .font(.system(size: 10, design: .monospaced))
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
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(commit.message)
                    .font(.system(size: 12))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(commit.shortId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.accentColor)

                    Text(commit.author)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(commit.formattedDate)
                        .font(.system(size: 10))
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
            task: "Implement user authentication with OAuth2 support and session management",
            projectPath: URL(fileURLWithPath: "/Users/test/project"),
            branchName: "claude/feature-auth-abc123",
            isolationMode: .worktree,
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
