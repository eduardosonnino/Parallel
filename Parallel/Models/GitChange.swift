import Foundation

enum GitChangeType: String, Codable {
    case added = "A"
    case modified = "M"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case ignored = "!"

    var displayName: String {
        switch self {
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .copied: return "Copied"
        case .untracked: return "Untracked"
        case .ignored: return "Ignored"
        }
    }

    var iconName: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .copied: return "doc.on.doc.fill"
        case .untracked: return "questionmark.circle.fill"
        case .ignored: return "eye.slash.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .added: return "green"
        case .modified: return "orange"
        case .deleted: return "red"
        case .renamed: return "blue"
        case .copied: return "purple"
        case .untracked: return "gray"
        case .ignored: return "gray"
        }
    }
}

struct GitChange: Identifiable, Equatable, Codable {
    let id: UUID
    let filePath: String
    let changeType: GitChangeType
    let oldPath: String?
    let linesAdded: Int
    let linesRemoved: Int
    let diff: String?

    init(
        id: UUID = UUID(),
        filePath: String,
        changeType: GitChangeType,
        oldPath: String? = nil,
        linesAdded: Int = 0,
        linesRemoved: Int = 0,
        diff: String? = nil
    ) {
        self.id = id
        self.filePath = filePath
        self.changeType = changeType
        self.oldPath = oldPath
        self.linesAdded = linesAdded
        self.linesRemoved = linesRemoved
        self.diff = diff
    }

    var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    var directory: String {
        URL(fileURLWithPath: filePath).deletingLastPathComponent().path
    }

    var stats: String {
        if linesAdded == 0 && linesRemoved == 0 {
            return ""
        }
        return "+\(linesAdded) -\(linesRemoved)"
    }
}

struct GitBranch: Identifiable, Equatable {
    let id: UUID
    let name: String
    let isRemote: Bool
    let isCurrent: Bool
    let lastCommit: String?
    let aheadBehind: (ahead: Int, behind: Int)?

    init(
        id: UUID = UUID(),
        name: String,
        isRemote: Bool = false,
        isCurrent: Bool = false,
        lastCommit: String? = nil,
        aheadBehind: (ahead: Int, behind: Int)? = nil
    ) {
        self.id = id
        self.name = name
        self.isRemote = isRemote
        self.isCurrent = isCurrent
        self.lastCommit = lastCommit
        self.aheadBehind = aheadBehind
    }

    var displayName: String {
        if isRemote {
            return name.replacingOccurrences(of: "origin/", with: "")
        }
        return name
    }
}
