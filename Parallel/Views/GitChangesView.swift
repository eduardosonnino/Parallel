import SwiftUI

struct GitChangesView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFiles: Set<UUID> = []
    @State private var showDiff = false
    @State private var selectedDiffFile: GitChange?

    var allChanges: [(instance: ClaudeInstance, changes: [GitChange])] {
        appState.instances.compactMap { instance in
            if instance.changedFiles.isEmpty {
                return nil
            }
            return (instance, instance.changedFiles)
        }
    }

    var body: some View {
        HSplitView {
            // Changes list
            changesList
                .frame(minWidth: 300)

            // Diff viewer
            if let file = selectedDiffFile {
                DiffView(change: file)
            } else {
                emptyDiffView
            }
        }
    }

    private var changesList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Changes")
                    .font(.headline)

                Spacer()

                Text("\(appState.totalChangedFiles) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)

            Divider()

            if allChanges.isEmpty {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text("All instances have clean working directories")
                )
            } else {
                List(selection: $selectedFiles) {
                    ForEach(allChanges, id: \.instance.id) { item in
                        Section {
                            ForEach(item.changes) { change in
                                ChangeFileRow(change: change)
                                    .tag(change.id)
                                    .onTapGesture {
                                        selectedDiffFile = change
                                    }
                            }
                        } header: {
                            HStack {
                                StatusIndicator(status: item.instance.status, size: .small)
                                Text(item.instance.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Spacer()

                                Text(item.instance.branchName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Actions footer
            actionsFooter
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var actionsFooter: some View {
        HStack(spacing: 12) {
            Picker("Strategy", selection: $appState.commitStrategy) {
                ForEach(CommitStrategy.allCases, id: \.self) { strategy in
                    Label(strategy.displayName, systemImage: strategy.iconName)
                        .tag(strategy)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Spacer()

            Button("Commit All") {
                Task {
                    await appState.commitAllChanges()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.totalChangedFiles == 0)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyDiffView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Select a file to view diff")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ChangeFileRow: View {
    let change: GitChange
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: change.changeType.iconName)
                .foregroundColor(changeColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(change.fileName)
                    .font(.system(.subheadline, design: .monospaced))

                if !change.directory.isEmpty && change.directory != "." {
                    Text(change.directory)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !change.stats.isEmpty {
                HStack(spacing: 4) {
                    Text("+\(change.linesAdded)")
                        .foregroundColor(.green)
                    Text("-\(change.linesRemoved)")
                        .foregroundColor(.red)
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
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

struct DiffView: View {
    let change: GitChange

    var body: some View {
        VStack(spacing: 0) {
            // Diff header
            HStack {
                Image(systemName: change.changeType.iconName)
                    .foregroundColor(changeColor)

                Text(change.filePath)
                    .font(.system(.subheadline, design: .monospaced))

                Spacer()

                if !change.stats.isEmpty {
                    HStack(spacing: 8) {
                        Text("+\(change.linesAdded)")
                            .foregroundColor(.green)
                        Text("-\(change.linesRemoved)")
                            .foregroundColor(.red)
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Diff content
            ScrollView {
                if let diff = change.diff {
                    DiffContentView(diff: diff)
                } else {
                    Text("No diff available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
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

struct DiffContentView: View {
    let diff: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(diff.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                DiffLine(line: line, lineNumber: index + 1)
            }
        }
        .padding(8)
    }
}

struct DiffLine: View {
    let line: String
    let lineNumber: Int

    var body: some View {
        HStack(spacing: 0) {
            Text("\(lineNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(line)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(lineColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .background(lineBackground)
    }

    private var lineColor: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return .green
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return .red
        } else if line.hasPrefix("@@") {
            return .cyan
        }
        return .primary
    }

    private var lineBackground: Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") {
            return Color.green.opacity(0.1)
        } else if line.hasPrefix("-") && !line.hasPrefix("---") {
            return Color.red.opacity(0.1)
        }
        return .clear
    }
}

#Preview {
    GitChangesView()
        .environmentObject(AppState())
        .frame(width: 900, height: 600)
}
