//
//  ClaudeInstance.swift
//  Parallel
//
//  Model for a Claude Code instance on the canvas
//

import Foundation
import SwiftUI

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Pending Question

struct PendingQuestion: Identifiable {
    let id: UUID
    let question: String
    let context: String
    let options: [QuestionOption]
    let timestamp: Date

    struct QuestionOption: Identifiable {
        let id: UUID
        let label: String
        let shortcut: String?  // e.g., "Y", "N", "1", "2"

        init(label: String, shortcut: String? = nil) {
            self.id = UUID()
            self.label = label
            self.shortcut = shortcut
        }
    }

    init(question: String, context: String = "", options: [QuestionOption]) {
        self.id = UUID()
        self.question = question
        self.context = context
        self.options = options
        self.timestamp = Date()
    }

    // Common question types
    static func yesNo(question: String, context: String = "") -> PendingQuestion {
        PendingQuestion(
            question: question,
            context: context,
            options: [
                QuestionOption(label: "Yes", shortcut: "Y"),
                QuestionOption(label: "No", shortcut: "N")
            ]
        )
    }

    static func multipleChoice(question: String, context: String = "", choices: [String]) -> PendingQuestion {
        PendingQuestion(
            question: question,
            context: context,
            options: choices.enumerated().map { index, choice in
                QuestionOption(label: choice, shortcut: "\(index + 1)")
            }
        )
    }
}

// MARK: - Agent Type

enum AgentType: String, Codable {
    case coordinator
    case worker
}

// MARK: - Task Spec

struct TaskSpec: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let subtasks: [Subtask]
    let createdAt: Date

    struct Subtask: Codable, Identifiable {
        let id: UUID
        let title: String
        let description: String
        var assignedWorkerId: UUID?

        init(id: UUID = UUID(), title: String, description: String, assignedWorkerId: UUID? = nil) {
            self.id = id
            self.title = title
            self.description = description
            self.assignedWorkerId = assignedWorkerId
        }
    }

    init(id: UUID = UUID(), title: String, description: String, subtasks: [Subtask], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.subtasks = subtasks
        self.createdAt = createdAt
    }
}

// MARK: - Jira Ticket (Mock)

struct JiraTicket: Codable, Identifiable {
    let id: UUID
    let key: String      // e.g., "PROJ-123"
    let title: String
    var status: JiraStatus
    let url: String?

    enum JiraStatus: String, Codable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case done = "Done"
    }

    init(id: UUID = UUID(), key: String, title: String, status: JiraStatus = .inProgress, url: String? = nil) {
        self.id = id
        self.key = key
        self.title = title
        self.status = status
        self.url = url
    }
}

// MARK: - Worker Question

struct WorkerQuestion: Identifiable {
    let id: UUID
    let workerId: UUID
    let workerName: String
    let question: PendingQuestion
    let timestamp: Date
    var answered: Bool
    var answer: String?

    init(id: UUID = UUID(), workerId: UUID, workerName: String, question: PendingQuestion, timestamp: Date = Date(), answered: Bool = false, answer: String? = nil) {
        self.id = id
        self.workerId = workerId
        self.workerName = workerName
        self.question = question
        self.timestamp = timestamp
        self.answered = answered
        self.answer = answer
    }
}

// MARK: - Instance Status

enum InstanceStatus: String, Codable, CaseIterable {
    case idle
    case running
    case waiting      // Blocked, waiting for user input
    case ready
    case error
    case completed
    case merged
    // Coordinator-specific statuses
    case specifying   // Coordinator is writing spec
    case spawning     // Coordinator is creating workers
    case supervising  // Coordinator is monitoring workers

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .waiting: return "Waiting"
        case .ready: return "Ready"
        case .error: return "Error"
        case .completed: return "Completed"
        case .merged: return "Merged"
        case .specifying: return "Writing Spec"
        case .spawning: return "Spawning"
        case .supervising: return "Supervising"
        }
    }

    var color: Color {
        switch self {
        case .idle: return DesignColors.statusIdle
        case .running: return DesignColors.statusRunning
        case .waiting: return DesignColors.statusWaiting
        case .ready: return DesignColors.statusReady
        case .error: return DesignColors.statusError
        case .completed: return DesignColors.statusReady
        case .merged: return DesignColors.statusMerged
        case .specifying: return DesignColors.statusRunning
        case .spawning: return DesignColors.statusRunning
        case .supervising: return Color(hex: "#AF52DE")  // Purple for coordinator
        }
    }

    var isActive: Bool {
        switch self {
        case .running, .waiting, .specifying, .spawning, .supervising:
            return true
        default:
            return false
        }
    }
}

// MARK: - Claude Instance

@Observable
final class ClaudeInstance: Identifiable {
    // MARK: - Identity

    let id: UUID

    // MARK: - Position & Layout

    var x: Double
    var y: Double
    var organicX: Double?
    var organicY: Double?
    var zIndex: Int

    // MARK: - Instance Info

    var name: String
    var task: String
    var branchName: String
    var status: InstanceStatus
    var workingDirectory: String?
    var mainRepoPath: String?  // Original repo path (source of truth)

    // MARK: - Chat

    var messages: [ChatMessage] = []
    var pendingQuestion: PendingQuestion?

    // MARK: - Agent Hierarchy

    var agentType: AgentType = .worker
    var parentId: UUID?                        // Workers reference their coordinator
    var workerIds: [UUID] = []                 // Coordinators track their workers

    // MARK: - Coordinator-Specific

    var spec: TaskSpec?                        // Generated specification
    var jiraTicket: JiraTicket?                // Mock Jira ticket
    var pendingWorkerQuestions: [WorkerQuestion] = []  // Aggregated questions from workers

    // MARK: - Worker-Specific

    var subtask: String?                       // Assigned subtask from coordinator

    // MARK: - Remix Groups

    var groupId: UUID?                         // Cards in same group share this ID
    var isOriginal: Bool = true                // First card in group is original

    // MARK: - Request Tracking

    var completedRequests: [String] = []       // Track what the agent has already done

    // MARK: - Timestamps

    var createdAt: Date
    var lastActivityAt: Date

    // MARK: - Computed Properties

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }

    var displayName: String {
        name.isEmpty ? "Untitled Instance" : name
    }

    var shortBranchName: String {
        branchName.replacingOccurrences(of: "claude/", with: "")
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String = "",
        task: String = "",
        x: Double = 0,
        y: Double = 0,
        zIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.task = task
        self.branchName = "claude/\(name.lowercased().replacingOccurrences(of: " ", with: "-"))-\(id.uuidString.prefix(6))"
        self.x = x
        self.y = y
        self.zIndex = zIndex
        self.status = .idle
        self.createdAt = Date()
        self.lastActivityAt = Date()
    }
}

// MARK: - Factory Methods

extension ClaudeInstance {
    static func create(
        name: String,
        task: String,
        at position: CGPoint = .zero
    ) -> ClaudeInstance {
        ClaudeInstance(
            name: name,
            task: task,
            x: position.x,
            y: position.y
        )
    }
}

// MARK: - Chat Methods

extension ClaudeInstance {
    func addMessage(role: ChatMessage.MessageRole, content: String) {
        let message = ChatMessage(role: role, content: content)
        messages.append(message)
        lastActivityAt = Date()
    }

    func askQuestion(_ question: PendingQuestion) {
        pendingQuestion = question
        status = .waiting
        lastActivityAt = Date()
    }

    func answerQuestion(with option: PendingQuestion.QuestionOption) {
        guard let question = pendingQuestion else { return }

        // Add the question and answer to chat history
        addMessage(role: .assistant, content: question.question)
        addMessage(role: .user, content: option.label)

        // Clear the pending question and resume
        pendingQuestion = nil
        status = .running
        lastActivityAt = Date()
    }

    func answerQuestionWithText(_ text: String) {
        guard let question = pendingQuestion else { return }

        // Add the question and answer to chat history
        addMessage(role: .assistant, content: question.question)
        addMessage(role: .user, content: text)

        // Clear the pending question and resume
        pendingQuestion = nil
        status = .running
        lastActivityAt = Date()
    }

    /// Updates the task/title from a user message if needed
    /// Only updates on the FIRST USER message - subsequent messages don't change the title
    /// Uses Claude API to generate a smart, concise title
    func updateTaskIfNeeded(from text: String) {
        // Only update if this is the first user message
        // (ignore assistant messages like "Remix ready")
        let userMessageCount = messages.filter { $0.role == .user }.count
        guard userMessageCount == 0 else { return }

        // Set a temporary title immediately (will be replaced by AI-generated one)
        let tempTitle = createFallbackTitle(from: text)
        task = tempTitle

        // Generate smart title asynchronously using Claude API
        Task {
            if let smartTitle = await ClaudeAPIService.shared.generateSmartTitle(from: text) {
                await MainActor.run {
                    self.task = smartTitle
                }
            }
        }
    }

    /// Creates a simple fallback title while waiting for AI
    private func createFallbackTitle(from text: String) -> String {
        var title = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common prefixes
        let prefixesToRemove = ["please ", "can you ", "could you ", "i want to ", "i need to ", "help me ", "i'd like to ", "let's "]
        for prefix in prefixesToRemove {
            if title.lowercased().hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
                break
            }
        }

        // Capitalize first letter
        if let first = title.first {
            title = first.uppercased() + title.dropFirst()
        }

        // Truncate
        if title.count > 50 {
            let truncated = String(title.prefix(50))
            if let lastSpace = truncated.lastIndex(of: " ") {
                title = String(truncated[..<lastSpace]) + "..."
            } else {
                title = truncated + "..."
            }
        }

        return title
    }
}
