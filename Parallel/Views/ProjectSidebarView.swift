import SwiftUI

struct ProjectSidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""

    var filteredInstances: [ClaudeInstance] {
        if searchText.isEmpty {
            return appState.instances
        }
        return appState.instances.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.task.localizedCaseInsensitiveContains(searchText) ||
            $0.branchName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search instances...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Instance list
            List(selection: $appState.selectedInstanceId) {
                Section("Active") {
                    ForEach(filteredInstances.filter { $0.status.isActive }) { instance in
                        SidebarInstanceRow(instance: instance)
                            .tag(instance.id)
                    }
                }

                Section("Ready") {
                    ForEach(filteredInstances.filter { $0.status == .ready || $0.status == .completed }) { instance in
                        SidebarInstanceRow(instance: instance)
                            .tag(instance.id)
                    }
                }

                Section("Other") {
                    ForEach(filteredInstances.filter { !$0.status.isActive && $0.status != .ready && $0.status != .completed }) { instance in
                        SidebarInstanceRow(instance: instance)
                            .tag(instance.id)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Quick stats
            quickStats
        }
    }

    private var quickStats: some View {
        VStack(spacing: 8) {
            HStack {
                Label("\(appState.instances.filter { $0.status.isActive }.count) active", systemImage: "play.circle")
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack {
                Label("\(appState.readyInstancesCount) ready", systemImage: "checkmark.circle")
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.green)

            HStack {
                Label("\(appState.totalChangedFiles) files changed", systemImage: "doc.text")
                Spacer()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct SidebarInstanceRow: View {
    let instance: ClaudeInstance
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            StatusIndicator(status: instance.status, size: .small)

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(instance.task)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if instance.changedFiles.count > 0 {
                Text("\(instance.changedFiles.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProjectSidebarView()
        .environmentObject(AppState())
        .frame(width: 250)
}
