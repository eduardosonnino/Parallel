import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarTab = .features

    enum SidebarTab: String, CaseIterable {
        case features = "Features"
        case instances = "Instances"
        case changes = "Changes"
        case build = "Build"

        var icon: String {
            switch self {
            case .features: return "list.bullet.rectangle"
            case .instances: return "terminal"
            case .changes: return "arrow.triangle.branch"
            case .build: return "hammer"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                ProjectHeader()

                Divider()

                List(selection: $selectedTab) {
                    ForEach(SidebarTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                InstancesSummary()
            }
            .frame(minWidth: 200)
        } content: {
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
            .frame(minWidth: 500)
        } detail: {
            if let instance = appState.selectedInstance {
                InstanceDetailView(instance: instance)
            } else {
                EmptyDetailView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    appState.showNewInstanceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Claude Instance")

                Button {
                    Task {
                        await appState.refreshGitStatus()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Git Status")

                Spacer()

                BuildStatusButton()
            }
        }
        .sheet(isPresented: $appState.showNewInstanceSheet) {
            NewInstanceSheet()
        }
        .onAppear {
            if appState.currentProject == nil {
                showWelcome()
            }
        }
    }

    private func showWelcome() {
        // Show welcome or prompt to open project
    }
}

struct ProjectHeader: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let project = appState.currentProject {
                Text(project.name)
                    .font(.headline)
                Text(project.path.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Button("Open Project...") {
                    appState.openProjectPicker()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InstancesSummary: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                StatusDot(color: .green)
                Text("\(appState.readyInstancesCount) Ready")
                    .font(.caption)
                Spacer()
                Text("\(appState.instances.count) Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                Text("\(appState.totalChangedFiles) files changed")
                    .font(.caption)
                Spacer()
            }

            if appState.allInstancesReady && !appState.instances.isEmpty {
                Button {
                    Task {
                        await appState.runBuildIfAllReady()
                    }
                } label: {
                    Label("Run Build", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
    }
}

struct InstancesGridView: View {
    @EnvironmentObject var appState: AppState

    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            if appState.instances.isEmpty {
                EmptyInstancesView()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(appState.instances) { instance in
                        InstanceCardView(instance: instance)
                            .onTapGesture {
                                appState.selectedInstanceId = instance.id
                            }
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct EmptyInstancesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Claude Instances")
                .font(.title2)

            Text("Create a new instance to start working on your project in parallel")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                appState.showNewInstanceSheet = true
            } label: {
                Label("New Instance", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.currentProject == nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Select an Instance")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Click on an instance to view its details and output")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BuildStatusButton: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button {
            Task {
                await appState.runBuildIfAllReady()
            }
        } label: {
            HStack(spacing: 6) {
                if appState.isRunningBuild {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Circle()
                        .fill(appState.allInstancesReady ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }

                Text(appState.isRunningBuild ? "Building..." : (appState.allInstancesReady ? "Ready" : "Working"))
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(!appState.allInstancesReady || appState.isRunningBuild)
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
