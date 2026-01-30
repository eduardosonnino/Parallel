import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarTab = .features
    @State private var sidebarWidth: CGFloat = 220

    enum SidebarTab: String, CaseIterable {
        case features = "Features"
        case instances = "Instances"
        case changes = "Changes"
        case build = "Build"

        var icon: String {
            switch self {
            case .features: return "square.stack.3d.up"
            case .instances: return "terminal"
            case .changes: return "arrow.triangle.branch"
            case .build: return "hammer"
            }
        }

        var shortcut: String {
            switch self {
            case .features: return "1"
            case .instances: return "2"
            case .changes: return "3"
            case .build: return "4"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 200, maxWidth: 280)
        } content: {
            mainContent
                .frame(minWidth: 600)
        } detail: {
            detailView
        }
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $appState.showNewInstanceSheet) {
            NewInstanceSheet()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Project header
            projectHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            // Navigation
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarButton(
                        title: tab.rawValue,
                        icon: tab.icon,
                        isSelected: selectedTab == tab,
                        badge: badgeCount(for: tab)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer()

            Divider()
                .padding(.horizontal, 16)

            // Stats footer
            statsFooter
                .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var projectHeader: some View {
        HStack(spacing: 10) {
            if let project = appState.currentProject {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 32, height: 32)

                    Text(String(project.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(project.path.lastPathComponent)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    appState.openProjectPicker()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Change Project")
            } else {
                Button {
                    appState.openProjectPicker()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                        Text("Open Project")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var statsFooter: some View {
        VStack(spacing: 12) {
            // Progress indicator
            if !appState.instances.isEmpty {
                VStack(spacing: 6) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(appState.readyInstancesCount)/\(appState.instances.count)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15))

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(width: geo.size.width * progressPercentage)
                        }
                    }
                    .frame(height: 4)
                }
            }

            // Quick stats
            HStack(spacing: 16) {
                MiniStat(value: appState.instances.count, label: "Active", color: .blue)
                MiniStat(value: appState.totalChangedFiles, label: "Files", color: .orange)
                MiniStat(value: appState.orchestrator.stats.queued, label: "Queued", color: .purple)
            }

            // Build button
            if appState.canBuildMainProject {
                Button {
                    Task { await appState.runBuild() }
                } label: {
                    HStack(spacing: 6) {
                        if appState.isRunningBuild {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                        }
                        Text(appState.isRunningBuild ? "Building..." : "Run Build")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(appState.isRunningBuild)
            }
        }
    }

    private var progressPercentage: Double {
        guard !appState.instances.isEmpty else { return 0 }
        return Double(appState.readyInstancesCount) / Double(appState.instances.count)
    }

    private func badgeCount(for tab: SidebarTab) -> Int? {
        switch tab {
        case .features:
            let count = appState.orchestrator.stats.inProgress
            return count > 0 ? count : nil
        case .instances:
            let count = appState.instances.filter { $0.status.isActive }.count
            return count > 0 ? count : nil
        case .changes:
            let count = appState.totalChangedFiles
            return count > 0 ? count : nil
        case .build:
            return nil
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            switch selectedTab {
            case .features:
                FeatureTrackerView(orchestrator: appState.orchestrator)
            case .instances:
                InstancesGridView()
            case .changes:
                GitChangesView()
            case .build:
                BuildControlView()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Detail View

    private var detailView: some View {
        Group {
            if let instance = appState.selectedInstance {
                InstanceDetailView(instance: instance)
            } else {
                EmptyDetailView()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                appState.showNewInstanceSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .help("New Instance (Cmd+N)")
            .keyboardShortcut("n", modifiers: .command)

            Button {
                Task { await appState.refreshGitStatus() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh (Cmd+R)")
            .keyboardShortcut("r", modifiers: .command)

            Spacer()

            // Status pill
            StatusPill(appState: appState)
        }
    }
}

// MARK: - Supporting Views

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let badge: Int?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()

                if let badge = badge {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.08) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MiniStat: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatusPill: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        if appState.isRunningBuild {
            return .blue
        } else if appState.allInstancesReady && !appState.instances.isEmpty {
            return .green
        } else if appState.instances.contains(where: { $0.status == .error }) {
            return .red
        } else if !appState.instances.isEmpty {
            return .orange
        }
        return .secondary
    }

    private var statusText: String {
        if appState.isRunningBuild {
            return "Building"
        } else if appState.allInstancesReady && !appState.instances.isEmpty {
            return "Ready"
        } else if appState.instances.contains(where: { $0.status == .error }) {
            return "Error"
        } else if !appState.instances.isEmpty {
            return "Working"
        }
        return "Idle"
    }
}

struct InstancesGridView: View {
    @EnvironmentObject var appState: AppState

    let columns = [
        GridItem(.adaptive(minimum: 320, maximum: 420), spacing: 16)
    ]

    var body: some View {
        Group {
            if appState.instances.isEmpty {
                EmptyInstancesView()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(appState.instances) { instance in
                            InstanceCardView(instance: instance)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        appState.selectedInstanceId = instance.id
                                    }
                                }
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

struct EmptyInstancesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "terminal")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            VStack(spacing: 8) {
                Text("No Active Instances")
                    .font(.system(size: 17, weight: .semibold))

                Text("Create a Claude instance to start working\non your project in parallel")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button {
                appState.showNewInstanceSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("New Instance")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.currentProject == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 64, height: 64)

                Image(systemName: "sidebar.right")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary.opacity(0.5))
            }

            VStack(spacing: 4) {
                Text("No Selection")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)

                Text("Select an instance to view details")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1200, height: 700)
}
