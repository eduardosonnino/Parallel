import SwiftUI

struct FeatureTrackerView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var orchestrator: Orchestrator
    @State private var viewMode: ViewMode = .board
    @State private var showAddFeature = false
    @State private var showImportSheet = false
    @State private var selectedFeature: Feature?
    @State private var filterType: FeatureType?
    @State private var filterPriority: FeaturePriority?
    @State private var searchText = ""

    enum ViewMode: String, CaseIterable {
        case board = "Board"
        case list = "List"

        var icon: String {
            switch self {
            case .board: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    var filteredFeatures: [Feature] {
        orchestrator.features.filter { feature in
            let matchesSearch = searchText.isEmpty ||
                feature.title.localizedCaseInsensitiveContains(searchText) ||
                feature.description.localizedCaseInsensitiveContains(searchText)

            let matchesType = filterType == nil || feature.type == filterType
            let matchesPriority = filterPriority == nil || feature.priority == filterPriority

            return matchesSearch && matchesType && matchesPriority
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats and controls
            headerView

            Divider()

            // Main content
            Group {
                switch viewMode {
                case .board:
                    boardView
                case .list:
                    listView
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showAddFeature) {
            AddFeatureSheet(orchestrator: orchestrator)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportFeaturesSheet(orchestrator: orchestrator)
        }
        .sheet(item: $selectedFeature) { feature in
            FeatureDetailSheet(feature: feature, orchestrator: orchestrator, appState: appState)
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 24) {
                StatBadge(label: "Total", value: orchestrator.stats.totalFeatures, color: .secondary)
                StatBadge(label: "Queued", value: orchestrator.stats.queued, color: .yellow)
                StatBadge(label: "Active", value: orchestrator.stats.inProgress, color: .blue)
                StatBadge(label: "Review", value: orchestrator.stats.review, color: .purple)
                StatBadge(label: "Done", value: orchestrator.stats.completed, color: .green)

                Spacer()

                // View mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }

            // Controls row
            HStack(spacing: 12) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search features...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 250)

                // Filters
                Menu {
                    Button("All Types") { filterType = nil }
                    Divider()
                    ForEach(FeatureType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            Label(type.displayName, systemImage: type.iconName)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(filterType?.displayName ?? "Type")
                    }
                }

                Menu {
                    Button("All Priorities") { filterPriority = nil }
                    Divider()
                    ForEach(FeaturePriority.allCases, id: \.self) { priority in
                        Button {
                            filterPriority = priority
                        } label: {
                            Label(priority.displayName, systemImage: priority.iconName)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "flag")
                        Text(filterPriority?.displayName ?? "Priority")
                    }
                }

                Spacer()

                // Auto-assign toggle
                Toggle(isOn: $orchestrator.autoAssignEnabled) {
                    Label("Auto-assign", systemImage: "bolt.circle")
                }
                .toggleStyle(.switch)

                // Actions
                Button {
                    showImportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Import Features")

                Button {
                    showAddFeature = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach([FeatureStatus.backlog, .queued, .inProgress, .review, .merged], id: \.self) { status in
                    BoardColumn(
                        status: status,
                        features: filteredFeatures.filter { $0.status == status },
                        orchestrator: orchestrator,
                        onSelect: { selectedFeature = $0 }
                    )
                }
            }
            .padding(16)
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredFeatures.sorted { $0.priority > $1.priority }) { feature in
                FeatureListRow(feature: feature, orchestrator: orchestrator, appState: appState)
                    .onTapGesture {
                        selectedFeature = feature
                    }
            }
        }
        .listStyle(.inset)
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct BoardColumn: View {
    let status: FeatureStatus
    let features: [Feature]
    let orchestrator: Orchestrator
    let onSelect: (Feature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column header
            HStack {
                Image(systemName: status.iconName)
                    .foregroundColor(statusColor)
                Text(status.displayName)
                    .font(.headline)

                Spacer()

                Text("\(features.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.1))
            .cornerRadius(8)

            // Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(features.sorted { $0.priority > $1.priority }) { feature in
                        FeatureCard(feature: feature, orchestrator: orchestrator)
                            .onTapGesture {
                                onSelect(feature)
                            }
                    }
                }
            }

            Spacer()
        }
        .frame(width: 280)
        .padding(8)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
    }

    private var statusColor: Color {
        switch status {
        case .backlog: return .secondary
        case .queued: return .yellow
        case .inProgress: return .blue
        case .review: return .purple
        case .merged, .completed: return .green
        }
    }
}

struct FeatureCard: View {
    let feature: Feature
    let orchestrator: Orchestrator
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: feature.type.iconName)
                    .font(.caption)
                    .foregroundColor(typeColor)

                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Spacer()

                Image(systemName: feature.priority.iconName)
                    .font(.caption)
                    .foregroundColor(priorityColor)
            }

            // Description preview
            if !feature.description.isEmpty {
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Tags
            if !feature.tags.isEmpty {
                HStack {
                    ForEach(feature.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    if feature.tags.count > 3 {
                        Text("+\(feature.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Footer
            HStack {
                if feature.isBlocked {
                    Label("Blocked", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Spacer()

                if feature.assignedInstanceId != nil {
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                Text(feature.formattedDuration)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(feature.isBlocked ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 4 : 2)
        .onHover { isHovered = $0 }
    }

    private var typeColor: Color {
        switch feature.type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .gray
        }
    }

    private var priorityColor: Color {
        switch feature.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

struct FeatureListRow: View {
    let feature: Feature
    let orchestrator: Orchestrator
    let appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: feature.type.iconName)
                .foregroundColor(typeColor)
                .frame(width: 20)

            // Priority
            Image(systemName: feature.priority.iconName)
                .font(.caption)
                .foregroundColor(priorityColor)

            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status badge
            Text(feature.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .foregroundColor(statusColor)
                .clipShape(Capsule())

            // Actions
            if feature.status == .backlog {
                Button("Queue") {
                    orchestrator.moveFeature(feature, to: .queued)
                }
                .buttonStyle(.borderless)
            } else if feature.status == .review {
                Button("Merge") {
                    Task {
                        await orchestrator.mergeFeature(feature)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var typeColor: Color {
        switch feature.type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .gray
        }
    }

    private var priorityColor: Color {
        switch feature.priority {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }

    private var statusColor: Color {
        switch feature.status {
        case .backlog: return .secondary
        case .queued: return .yellow
        case .inProgress: return .blue
        case .review: return .purple
        case .merged, .completed: return .green
        }
    }
}

struct AddFeatureSheet: View {
    @ObservedObject var orchestrator: Orchestrator
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var type: FeatureType = .feature
    @State private var priority: FeaturePriority = .medium
    @State private var tags = ""
    @State private var addToQueue = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Feature")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            Form {
                TextField("Title", text: $title)

                TextEditor(text: $description)
                    .frame(height: 80)

                Picker("Type", selection: $type) {
                    ForEach(FeatureType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.iconName).tag(t)
                    }
                }

                Picker("Priority", selection: $priority) {
                    ForEach(FeaturePriority.allCases, id: \.self) { p in
                        Label(p.displayName, systemImage: p.iconName).tag(p)
                    }
                }

                TextField("Tags (comma separated)", text: $tags)

                Toggle("Add to queue immediately", isOn: $addToQueue)
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add Feature") {
                    let tagList = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    let feature = Feature(
                        title: title,
                        description: description,
                        type: type,
                        priority: priority,
                        status: addToQueue ? .queued : .backlog,
                        tags: tagList
                    )
                    orchestrator.addFeature(feature)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 450, height: 500)
    }
}

struct ImportFeaturesSheet: View {
    @ObservedObject var orchestrator: Orchestrator
    @Environment(\.dismiss) var dismiss

    @State private var inputText = ""
    @State private var parsedFeatures: [Feature] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import Features")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Paste features (one per line)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Format: [type] title - description #tag1 #tag2")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)

                Button("Parse") {
                    parsedFeatures = orchestrator.importFeatures(from: inputText)
                }

                if !parsedFeatures.isEmpty {
                    Text("Parsed \(parsedFeatures.count) features:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    List(parsedFeatures) { feature in
                        HStack {
                            Image(systemName: feature.type.iconName)
                            Text(feature.title)
                            Spacer()
                            Text(feature.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 150)
                }
            }
            .padding()

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Import \(parsedFeatures.count) Features") {
                    orchestrator.addFeatures(parsedFeatures)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedFeatures.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 500, height: 550)
    }
}

struct FeatureDetailSheet: View {
    let feature: Feature
    @ObservedObject var orchestrator: Orchestrator
    let appState: AppState
    @Environment(\.dismiss) var dismiss

    var linkedInstance: ClaudeInstance? {
        guard let instanceId = feature.assignedInstanceId else { return nil }
        return appState.instances.first { $0.id == instanceId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: feature.type.iconName)
                    .font(.title2)
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status and priority
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(feature.status.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        VStack(alignment: .leading) {
                            Text("Priority")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Label(feature.priority.displayName, systemImage: feature.priority.iconName)
                                .font(.subheadline)
                        }

                        VStack(alignment: .leading) {
                            Text("Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Label(feature.type.displayName, systemImage: feature.type.iconName)
                                .font(.subheadline)
                        }

                        Spacer()
                    }

                    // Description
                    if !feature.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(feature.description)
                                .font(.subheadline)
                        }
                    }

                    // Tags
                    if !feature.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                ForEach(feature.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }

                    // Linked instance
                    if let instance = linkedInstance {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Assigned Instance")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                StatusIndicator(status: instance.status)
                                Text(instance.name)
                                Spacer()
                                Text(instance.branchName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }

                    // Branch
                    if let branch = feature.branchName {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Branch")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(branch)
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }

                    // Times
                    HStack(spacing: 24) {
                        VStack(alignment: .leading) {
                            Text("Created")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(feature.createdAt, style: .relative)
                                .font(.caption)
                        }

                        if let started = feature.startedAt {
                            VStack(alignment: .leading) {
                                Text("Started")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(started, style: .relative)
                                    .font(.caption)
                            }
                        }

                        if let completed = feature.completedAt {
                            VStack(alignment: .leading) {
                                Text("Completed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(completed, style: .relative)
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                if feature.status == .backlog {
                    Button("Queue") {
                        orchestrator.moveFeature(feature, to: .queued)
                        dismiss()
                    }
                }

                if feature.status == .queued {
                    Button("Start Now") {
                        Task {
                            await orchestrator.startFeature(feature)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if feature.status == .review {
                    Button("Merge & Build") {
                        Task {
                            await orchestrator.mergeFeature(feature)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    orchestrator.removeFeature(feature)
                    dismiss()
                }
            }
            .padding(20)
        }
        .frame(width: 500, height: 550)
    }
}

#Preview {
    FeatureTrackerView(orchestrator: Orchestrator())
        .environmentObject(AppState())
        .frame(width: 1000, height: 600)
}
