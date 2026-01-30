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
            case .board: return "rectangle.split.3x1"
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
            headerView

            Divider()

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

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            // Stats
            HStack(spacing: 20) {
                CompactStat(value: orchestrator.stats.queued, label: "Queued", color: .yellow)
                CompactStat(value: orchestrator.stats.inProgress, label: "Active", color: .blue)
                CompactStat(value: orchestrator.stats.review, label: "Review", color: .purple)
                CompactStat(value: orchestrator.stats.completed, label: "Done", color: .green)
            }

            Spacer()

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(width: 180)

            // Filters
            FilterMenu(
                icon: "tag",
                title: filterType?.displayName ?? "Type",
                isActive: filterType != nil
            ) {
                Button("All Types") { filterType = nil }
                Divider()
                ForEach(FeatureType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        Label(type.displayName, systemImage: type.iconName)
                    }
                }
            }

            FilterMenu(
                icon: "flag",
                title: filterPriority?.displayName ?? "Priority",
                isActive: filterPriority != nil
            ) {
                Button("All Priorities") { filterPriority = nil }
                Divider()
                ForEach(FeaturePriority.allCases, id: \.self) { priority in
                    Button {
                        filterPriority = priority
                    } label: {
                        Label(priority.displayName, systemImage: priority.iconName)
                    }
                }
            }

            Divider()
                .frame(height: 20)

            // Auto-assign
            Toggle(isOn: $orchestrator.autoAssignEnabled) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("Auto")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            // View mode
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Actions
            Button {
                showImportSheet = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Import Features")

            Button {
                showAddFeature = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Board View

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach([FeatureStatus.backlog, .queued, .inProgress, .review, .merged], id: \.self) { status in
                    BoardColumn(
                        status: status,
                        features: filteredFeatures.filter { $0.status == status },
                        orchestrator: orchestrator,
                        onSelect: { selectedFeature = $0 }
                    )
                }
            }
            .padding(20)
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(filteredFeatures.sorted { $0.priority > $1.priority }) { feature in
                FeatureListRow(feature: feature, orchestrator: orchestrator, appState: appState)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFeature = feature
                    }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Supporting Views

struct CompactStat: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(value > 0 ? color : .secondary.opacity(0.5))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct FilterMenu<Content: View>: View {
    let icon: String
    let title: String
    let isActive: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .foregroundColor(isActive ? .accentColor : .secondary)
    }
}

struct BoardColumn: View {
    let status: FeatureStatus
    let features: [Feature]
    let orchestrator: Orchestrator
    let onSelect: (Feature) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(status.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(features.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .padding(.horizontal, 12)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(features.sorted { $0.priority > $1.priority }) { feature in
                        FeatureCard(feature: feature, orchestrator: orchestrator)
                            .onTapGesture {
                                onSelect(feature)
                            }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 260)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(10)
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
            // Header with type and priority
            HStack(spacing: 6) {
                Image(systemName: feature.type.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(typeColor)

                Text(feature.type.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                if feature.priority == .urgent || feature.priority == .high {
                    Image(systemName: feature.priority.iconName)
                        .font(.system(size: 9))
                        .foregroundColor(priorityColor)
                }
            }

            // Title
            Text(feature.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Description preview
            if !feature.description.isEmpty {
                Text(feature.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // Tags
            if !feature.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(feature.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    }
                    if feature.tags.count > 2 {
                        Text("+\(feature.tags.count - 2)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }

            // Footer
            HStack(spacing: 6) {
                if feature.isBlocked {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("Blocked")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                if feature.assignedInstanceId != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 8))
                        Text("Active")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.blue)
                }

                if feature.duration != nil {
                    Text(feature.formattedDuration)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    feature.isBlocked ? Color.red.opacity(0.4) :
                    (isHovered ? Color.accentColor.opacity(0.3) : Color.clear),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 4 : 2, y: 1)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var typeColor: Color {
        switch feature.type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .secondary
        }
    }

    private var priorityColor: Color {
        switch feature.priority {
        case .low: return .secondary
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
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Type indicator
            Circle()
                .fill(typeColor)
                .frame(width: 8, height: 8)

            // Priority
            if feature.priority == .urgent || feature.priority == .high {
                Image(systemName: feature.priority.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(priorityColor)
                    .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }

            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 12, weight: .medium))

                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Tags
            if !feature.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(feature.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
            }

            // Status badge
            Text(feature.status.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

            // Quick actions
            if feature.status == .backlog {
                Button {
                    orchestrator.moveFeature(feature, to: .queued)
                } label: {
                    Text("Queue")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.accentColor)
            } else if feature.status == .review {
                Button {
                    Task {
                        await orchestrator.mergeFeature(feature)
                    }
                } label: {
                    Text("Merge")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.green)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { isHovered = $0 }
    }

    private var typeColor: Color {
        switch feature.type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .secondary
        }
    }

    private var priorityColor: Color {
        switch feature.priority {
        case .low: return .secondary
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

// MARK: - Sheets

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
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Feature")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Add a task to the backlog or queue")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(label: "Title") {
                        TextField("What needs to be done?", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }

                    FormField(label: "Description") {
                        TextEditor(text: $description)
                            .font(.system(size: 12))
                            .frame(height: 70)
                            .padding(4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    HStack(spacing: 16) {
                        FormField(label: "Type") {
                            Picker("", selection: $type) {
                                ForEach(FeatureType.allCases, id: \.self) { t in
                                    Label(t.displayName, systemImage: t.iconName).tag(t)
                                }
                            }
                            .labelsHidden()
                        }

                        FormField(label: "Priority") {
                            Picker("", selection: $priority) {
                                ForEach(FeaturePriority.allCases, id: \.self) { p in
                                    Label(p.displayName, systemImage: p.iconName).tag(p)
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    FormField(label: "Tags") {
                        TextField("api, auth, frontend", text: $tags)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle(isOn: $addToQueue) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add to queue")
                                .font(.system(size: 12, weight: .medium))
                            Text("Start working on this when a slot is available")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Add Feature") {
                    let tagList = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
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
                .keyboardShortcut(.return)
            }
            .padding(20)
        }
        .frame(width: 420, height: 480)
    }
}

struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            content()
        }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Features")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Paste a list of features to import")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Format: [type] title - description #tag1 #tag2")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)

                TextEditor(text: $inputText)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Button {
                    parsedFeatures = orchestrator.importFeatures(from: inputText)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 10))
                        Text("Parse")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .disabled(inputText.isEmpty)

                if !parsedFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Found \(parsedFeatures.count) features")
                                .font(.system(size: 11, weight: .medium))
                            Spacer()
                        }

                        ScrollView {
                            VStack(spacing: 4) {
                                ForEach(parsedFeatures) { feature in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(featureTypeColor(feature.type))
                                            .frame(width: 6, height: 6)
                                        Text(feature.title)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(feature.type.displayName)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }
            }
            .padding(20)

            Spacer()

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
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
        .frame(width: 460, height: 520)
    }

    private func featureTypeColor(_ type: FeatureType) -> Color {
        switch type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .secondary
        }
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
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: feature.type.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(typeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(feature.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(feature.type.displayName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status row
                    HStack(spacing: 24) {
                        DetailItem(label: "Status") {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 6, height: 6)
                                Text(feature.status.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }

                        DetailItem(label: "Priority") {
                            HStack(spacing: 4) {
                                Image(systemName: feature.priority.iconName)
                                    .font(.system(size: 10))
                                    .foregroundColor(priorityColor)
                                Text(feature.priority.displayName)
                                    .font(.system(size: 12))
                            }
                        }

                        DetailItem(label: "Complexity") {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { i in
                                    Circle()
                                        .fill(i <= feature.estimatedComplexity ? Color.blue : Color.secondary.opacity(0.2))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }

                        Spacer()
                    }

                    // Description
                    if !feature.description.isEmpty {
                        DetailItem(label: "Description") {
                            Text(feature.description)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                        }
                    }

                    // Tags
                    if !feature.tags.isEmpty {
                        DetailItem(label: "Tags") {
                            HStack(spacing: 6) {
                                ForEach(feature.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
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
                        DetailItem(label: "Assigned Instance") {
                            HStack(spacing: 10) {
                                StatusIndicator(status: instance.status)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(instance.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Text(instance.branchName)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }

                    // Branch
                    if let branch = feature.branchName, linkedInstance == nil {
                        DetailItem(label: "Branch") {
                            Text(branch)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    // Timeline
                    DetailItem(label: "Timeline") {
                        HStack(spacing: 20) {
                            TimelineItem(label: "Created", date: feature.createdAt)
                            if let started = feature.startedAt {
                                TimelineItem(label: "Started", date: started)
                            }
                            if let completed = feature.completedAt {
                                TimelineItem(label: "Completed", date: completed)
                            }
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    orchestrator.removeFeature(feature)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)

                Spacer()

                if feature.status == .backlog {
                    Button("Add to Queue") {
                        orchestrator.moveFeature(feature, to: .queued)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
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
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
    }

    private var typeColor: Color {
        switch feature.type {
        case .feature: return .purple
        case .bugfix: return .red
        case .refactor: return .blue
        case .docs: return .orange
        case .test: return .green
        case .chore: return .secondary
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

    private var priorityColor: Color {
        switch feature.priority {
        case .low: return .secondary
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

struct DetailItem<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }
}

struct TimelineItem: View {
    let label: String
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(date, style: .relative)
                .font(.system(size: 11))
        }
    }
}

#Preview {
    FeatureTrackerView(orchestrator: Orchestrator())
        .environmentObject(AppState())
        .frame(width: 1000, height: 600)
}
