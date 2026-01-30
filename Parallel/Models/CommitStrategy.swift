import Foundation

enum CommitStrategy: String, CaseIterable, Codable {
    case separateBranches = "separate_branches"
    case unifiedCommit = "unified_commit"
    case squashMerge = "squash_merge"

    var displayName: String {
        switch self {
        case .separateBranches:
            return "Separate Branches"
        case .unifiedCommit:
            return "Unified Commit"
        case .squashMerge:
            return "Squash & Merge"
        }
    }

    var description: String {
        switch self {
        case .separateBranches:
            return "Each Claude instance works on its own branch. Commits are kept separate for each feature."
        case .unifiedCommit:
            return "All changes from all instances are combined into a single commit on one branch."
        case .squashMerge:
            return "Each instance has its own branch, but all commits are squashed when merging to main."
        }
    }

    var iconName: String {
        switch self {
        case .separateBranches:
            return "arrow.triangle.branch"
        case .unifiedCommit:
            return "arrow.triangle.merge"
        case .squashMerge:
            return "rectangle.compress.vertical"
        }
    }
}

struct MergeConflict: Identifiable {
    let id: UUID
    let filePath: String
    let sourceBranch: String
    let targetBranch: String
    let conflictMarkers: [ConflictMarker]

    init(
        id: UUID = UUID(),
        filePath: String,
        sourceBranch: String,
        targetBranch: String,
        conflictMarkers: [ConflictMarker] = []
    ) {
        self.id = id
        self.filePath = filePath
        self.sourceBranch = sourceBranch
        self.targetBranch = targetBranch
        self.conflictMarkers = conflictMarkers
    }
}

struct ConflictMarker: Identifiable {
    let id: UUID
    let startLine: Int
    let endLine: Int
    let oursContent: String
    let theirsContent: String

    init(
        id: UUID = UUID(),
        startLine: Int,
        endLine: Int,
        oursContent: String,
        theirsContent: String
    ) {
        self.id = id
        self.startLine = startLine
        self.endLine = endLine
        self.oursContent = oursContent
        self.theirsContent = theirsContent
    }
}
