import Foundation
import Combine

@MainActor
class Orchestrator: ObservableObject {
    @Published var features: [Feature] = []
    @Published var maxConcurrentInstances: Int = 4
    @Published var autoAssignEnabled: Bool = true
    @Published var autoBuildOnMerge: Bool = true
    @Published var autoMergeOnComplete: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private weak var appState: AppState?

    // MARK: - Feature Management

    func addFeature(_ feature: Feature) {
        features.append(feature)
        if autoAssignEnabled {
            processQueue()
        }
    }

    func addFeatures(_ newFeatures: [Feature]) {
        features.append(contentsOf: newFeatures)
        if autoAssignEnabled {
            processQueue()
        }
    }

    func updateFeature(_ feature: Feature) {
        if let index = features.firstIndex(where: { $0.id == feature.id }) {
            features[index] = feature
        }
    }

    func removeFeature(_ feature: Feature) {
        features.removeAll { $0.id == feature.id }
        // Also remove from dependencies
        for i in features.indices {
            features[i].dependsOn.removeAll { $0 == feature.id }
            features[i].blockedBy.removeAll { $0 == feature.id }
        }
    }

    func moveFeature(_ feature: Feature, to status: FeatureStatus) {
        guard let index = features.firstIndex(where: { $0.id == feature.id }) else { return }

        var updated = features[index]
        updated.status = status

        if status == .inProgress && updated.startedAt == nil {
            updated.startedAt = Date()
        } else if status == .completed || status == .merged {
            updated.completedAt = Date()
        }

        features[index] = updated
    }

    // MARK: - Queue Processing

    func processQueue() {
        guard let appState = appState else { return }

        let activeCount = appState.instances.filter { $0.status.isActive }.count
        let availableSlots = maxConcurrentInstances - activeCount

        guard availableSlots > 0 else { return }

        // Get features ready to start (queued, not blocked, dependencies met)
        let readyFeatures = features
            .filter { $0.status == .queued && !$0.isBlocked && areDependenciesMet($0) }
            .sorted { $0.priority > $1.priority }
            .prefix(availableSlots)

        for feature in readyFeatures {
            Task {
                await startFeature(feature)
            }
        }
    }

    private func areDependenciesMet(_ feature: Feature) -> Bool {
        for depId in feature.dependsOn {
            if let dep = features.first(where: { $0.id == depId }) {
                if dep.status != .completed && dep.status != .merged {
                    return false
                }
            }
        }
        return true
    }

    func startFeature(_ feature: Feature) async {
        guard let appState = appState else { return }

        // Update feature status
        moveFeature(feature, to: .inProgress)

        // Create Claude instance for this feature
        let branchName = "claude/\(feature.type.rawValue)-\(feature.title.lowercased().replacingOccurrences(of: " ", with: "-").prefix(20))-\(UUID().uuidString.prefix(6))"

        // Build task description from feature
        let taskDescription = buildTaskDescription(for: feature)

        await appState.createInstance(
            name: feature.title,
            task: taskDescription,
            branchName: branchName,
            isolationMode: .worktree
        )

        // Link instance to feature
        if let instance = appState.instances.last {
            var updated = feature
            updated.assignedInstanceId = instance.id
            updated.branchName = branchName
            updateFeature(updated)
        }
    }

    private func buildTaskDescription(for feature: Feature) -> String {
        var parts: [String] = []

        parts.append("Task: \(feature.title)")

        if !feature.description.isEmpty {
            parts.append("\nDescription: \(feature.description)")
        }

        parts.append("\nType: \(feature.type.displayName)")
        parts.append("Priority: \(feature.priority.displayName)")

        if !feature.tags.isEmpty {
            parts.append("Tags: \(feature.tags.joined(separator: ", "))")
        }

        if !feature.notes.isEmpty {
            parts.append("\nNotes: \(feature.notes)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Instance Coordination

    func setAppState(_ appState: AppState) {
        self.appState = appState

        // Monitor instance completions
        appState.$instances
            .receive(on: DispatchQueue.main)
            .sink { [weak self] instances in
                self?.handleInstanceUpdates(instances)
            }
            .store(in: &cancellables)
    }

    private func handleInstanceUpdates(_ instances: [ClaudeInstance]) {
        for instance in instances {
            // Find linked feature
            guard let featureIndex = features.firstIndex(where: { $0.assignedInstanceId == instance.id }) else {
                continue
            }

            var feature = features[featureIndex]

            // Update feature status based on instance
            switch instance.status {
            case .completed:
                if feature.status == .inProgress {
                    feature.status = .review
                    features[featureIndex] = feature

                    // Auto-merge if enabled
                    if autoMergeOnComplete {
                        Task {
                            await mergeFeature(feature)
                        }
                    }
                }

            case .error, .stopped:
                if feature.status == .inProgress {
                    feature.status = .queued // Re-queue on failure
                    feature.assignedInstanceId = nil
                    features[featureIndex] = feature
                }

            default:
                break
            }
        }

        // Check if we can start more work
        if autoAssignEnabled {
            processQueue()
        }
    }

    func mergeFeature(_ feature: Feature) async {
        guard let appState = appState,
              let instanceId = feature.assignedInstanceId,
              let instance = appState.instances.first(where: { $0.id == instanceId }) else {
            return
        }

        await appState.mergeInstance(instance)

        // Update feature status
        var updated = feature
        updated.status = .merged
        updated.completedAt = Date()
        updateFeature(updated)

        // Unblock dependent features
        unblockDependents(of: feature)

        // Run build if enabled
        if autoBuildOnMerge {
            await appState.runBuild()
        }

        // Process queue for newly unblocked features
        if autoAssignEnabled {
            processQueue()
        }
    }

    private func unblockDependents(of feature: Feature) {
        for i in features.indices {
            features[i].blockedBy.removeAll { $0 == feature.id }
        }
    }

    // MARK: - Batch Operations

    func queueAllBacklog() {
        for i in features.indices where features[i].status == .backlog {
            features[i].status = .queued
        }
        processQueue()
    }

    func pauseAll() {
        autoAssignEnabled = false
        appState?.stopAllInstances()
    }

    func resumeAll() {
        autoAssignEnabled = true
        processQueue()
    }

    func mergeAllReady() async {
        let readyFeatures = features.filter { $0.status == .review }
        for feature in readyFeatures {
            await mergeFeature(feature)
        }
    }

    // MARK: - Statistics

    var stats: OrchestratorStats {
        OrchestratorStats(
            totalFeatures: features.count,
            backlog: features.filter { $0.status == .backlog }.count,
            queued: features.filter { $0.status == .queued }.count,
            inProgress: features.filter { $0.status == .inProgress }.count,
            review: features.filter { $0.status == .review }.count,
            completed: features.filter { $0.status == .completed || $0.status == .merged }.count,
            blocked: features.filter { $0.isBlocked }.count
        )
    }

    // MARK: - Import/Export

    func importFeatures(from text: String) -> [Feature] {
        // Parse simple format: one feature per line
        // Format: [type] title - description #tag1 #tag2
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> Feature? in
            var type: FeatureType = .feature
            var title = line
            var description = ""
            var tags: [String] = []

            // Extract type prefix
            if line.lowercased().hasPrefix("[bug]") || line.lowercased().hasPrefix("[fix]") {
                type = .bugfix
                title = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("[refactor]") {
                type = .refactor
                title = String(line.dropFirst(10)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("[docs]") {
                type = .docs
                title = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("[test]") {
                type = .test
                title = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("[chore]") {
                type = .chore
                title = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if line.lowercased().hasPrefix("[feature]") {
                title = String(line.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            }

            // Extract description after dash
            if let dashIndex = title.firstIndex(of: "-") {
                description = String(title[title.index(after: dashIndex)...]).trimmingCharacters(in: .whitespaces)
                title = String(title[..<dashIndex]).trimmingCharacters(in: .whitespaces)
            }

            // Extract tags
            let tagPattern = /#(\w+)/
            if let regex = try? NSRegularExpression(pattern: "#(\\w+)") {
                let range = NSRange(title.startIndex..., in: title)
                let matches = regex.matches(in: title, range: range)
                tags = matches.compactMap { match in
                    guard let tagRange = Range(match.range(at: 1), in: title) else { return nil }
                    return String(title[tagRange])
                }
                // Remove tags from title
                title = title.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }

            guard !title.isEmpty else { return nil }

            return Feature(
                title: title,
                description: description,
                type: type,
                tags: tags
            )
        }
    }

    func exportFeatures() -> String {
        features.map { feature in
            var line = "[\(feature.type.rawValue)] \(feature.title)"
            if !feature.description.isEmpty {
                line += " - \(feature.description)"
            }
            if !feature.tags.isEmpty {
                line += " " + feature.tags.map { "#\($0)" }.joined(separator: " ")
            }
            return line
        }.joined(separator: "\n")
    }
}

struct OrchestratorStats {
    let totalFeatures: Int
    let backlog: Int
    let queued: Int
    let inProgress: Int
    let review: Int
    let completed: Int
    let blocked: Int

    var completionRate: Double {
        guard totalFeatures > 0 else { return 0 }
        return Double(completed) / Double(totalFeatures)
    }

    var activeRate: Double {
        guard totalFeatures > 0 else { return 0 }
        return Double(inProgress) / Double(totalFeatures)
    }
}
