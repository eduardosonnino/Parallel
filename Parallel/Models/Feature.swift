import Foundation

enum FeatureStatus: String, Codable, CaseIterable {
    case backlog = "backlog"
    case queued = "queued"
    case inProgress = "in_progress"
    case review = "review"
    case merged = "merged"
    case completed = "completed"

    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .review: return "Ready for Review"
        case .merged: return "Merged"
        case .completed: return "Completed"
        }
    }

    var iconName: String {
        switch self {
        case .backlog: return "tray"
        case .queued: return "clock"
        case .inProgress: return "play.circle"
        case .review: return "eye"
        case .merged: return "arrow.triangle.merge"
        case .completed: return "checkmark.circle"
        }
    }

    var color: String {
        switch self {
        case .backlog: return "gray"
        case .queued: return "yellow"
        case .inProgress: return "blue"
        case .review: return "purple"
        case .merged: return "green"
        case .completed: return "green"
        }
    }
}

enum FeaturePriority: Int, Codable, CaseIterable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }

    var iconName: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .urgent: return "red"
        }
    }

    static func < (lhs: FeaturePriority, rhs: FeaturePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum FeatureType: String, Codable, CaseIterable {
    case feature = "feature"
    case bugfix = "bugfix"
    case refactor = "refactor"
    case docs = "docs"
    case test = "test"
    case chore = "chore"

    var displayName: String {
        switch self {
        case .feature: return "Feature"
        case .bugfix: return "Bug Fix"
        case .refactor: return "Refactor"
        case .docs: return "Documentation"
        case .test: return "Tests"
        case .chore: return "Chore"
        }
    }

    var iconName: String {
        switch self {
        case .feature: return "star"
        case .bugfix: return "ladybug"
        case .refactor: return "arrow.triangle.2.circlepath"
        case .docs: return "doc.text"
        case .test: return "checkmark.shield"
        case .chore: return "wrench"
        }
    }

    var color: String {
        switch self {
        case .feature: return "purple"
        case .bugfix: return "red"
        case .refactor: return "blue"
        case .docs: return "orange"
        case .test: return "green"
        case .chore: return "gray"
        }
    }
}

struct Feature: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var type: FeatureType
    var priority: FeaturePriority
    var status: FeatureStatus
    var assignedInstanceId: UUID?
    var dependsOn: [UUID]  // Feature IDs this depends on
    var blockedBy: [UUID]  // Feature IDs blocking this
    var tags: [String]
    var estimatedComplexity: Int  // 1-5 scale
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var branchName: String?
    var pullRequestURL: String?
    var notes: String

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        type: FeatureType = .feature,
        priority: FeaturePriority = .medium,
        status: FeatureStatus = .backlog,
        assignedInstanceId: UUID? = nil,
        dependsOn: [UUID] = [],
        blockedBy: [UUID] = [],
        tags: [String] = [],
        estimatedComplexity: Int = 3,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        branchName: String? = nil,
        pullRequestURL: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.type = type
        self.priority = priority
        self.status = status
        self.assignedInstanceId = assignedInstanceId
        self.dependsOn = dependsOn
        self.blockedBy = blockedBy
        self.tags = tags
        self.estimatedComplexity = estimatedComplexity
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.branchName = branchName
        self.pullRequestURL = pullRequestURL
        self.notes = notes
    }

    var isBlocked: Bool {
        !blockedBy.isEmpty
    }

    var canStart: Bool {
        status == .backlog || status == .queued
    }

    var isActive: Bool {
        status == .inProgress
    }

    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "--" }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    static func == (lhs: Feature, rhs: Feature) -> Bool {
        lhs.id == rhs.id
    }
}

struct FeatureGroup: Identifiable {
    let id: UUID
    var name: String
    var features: [Feature]
    var color: String

    init(id: UUID = UUID(), name: String, features: [Feature] = [], color: String = "blue") {
        self.id = id
        self.name = name
        self.features = features
        self.color = color
    }
}
