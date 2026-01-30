import Foundation

enum InstanceStatus: String, Codable {
    case idle = "Idle"
    case starting = "Starting"
    case running = "Running"
    case ready = "Ready"
    case completed = "Completed"
    case error = "Error"
    case stopped = "Stopped"

    var color: String {
        switch self {
        case .idle: return "gray"
        case .starting: return "yellow"
        case .running: return "blue"
        case .ready: return "green"
        case .completed: return "green"
        case .error: return "red"
        case .stopped: return "orange"
        }
    }

    var isActive: Bool {
        switch self {
        case .starting, .running:
            return true
        default:
            return false
        }
    }
}

struct ClaudeInstance: Identifiable, Equatable {
    let id: UUID
    var name: String
    var task: String
    var projectPath: URL
    var branchName: String
    var status: InstanceStatus
    var output: String
    var changedFiles: [GitChange]
    var commits: [GitCommit]
    var startTime: Date?
    var endTime: Date?
    var processId: Int32?
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        name: String,
        task: String,
        projectPath: URL,
        branchName: String,
        status: InstanceStatus = .idle,
        output: String = "",
        changedFiles: [GitChange] = [],
        commits: [GitCommit] = [],
        startTime: Date? = nil,
        endTime: Date? = nil,
        processId: Int32? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.task = task
        self.projectPath = projectPath
        self.branchName = branchName
        self.status = status
        self.output = output
        self.changedFiles = changedFiles
        self.commits = commits
        self.startTime = startTime
        self.endTime = endTime
        self.processId = processId
        self.errorMessage = errorMessage
    }

    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = endTime ?? Date()
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var isGreenLight: Bool {
        status == .ready || status == .completed
    }

    static func == (lhs: ClaudeInstance, rhs: ClaudeInstance) -> Bool {
        lhs.id == rhs.id
    }
}

struct GitCommit: Identifiable, Equatable {
    let id: String
    let message: String
    let author: String
    let date: Date
    let filesChanged: Int

    var shortId: String {
        String(id.prefix(7))
    }

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
