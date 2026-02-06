//
//  PersistenceService.swift
//  Parallel
//
//  Persists canvas state, agents, and version history for each project
//

import Foundation

// MARK: - Version Entry

struct VersionEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let agentId: UUID
    let agentName: String
    let action: String           // "created", "modified", "completed", "merged"
    let summary: String          // AI-generated or auto summary
    let filesChanged: [String]   // List of files modified

    init(agentId: UUID, agentName: String, action: String, summary: String, filesChanged: [String] = []) {
        self.id = UUID()
        self.timestamp = Date()
        self.agentId = agentId
        self.agentName = agentName
        self.action = action
        self.summary = summary
        self.filesChanged = filesChanged
    }
}

// MARK: - Persisted Instance

struct PersistedInstance: Codable {
    let id: UUID
    let name: String
    let task: String
    let branchName: String
    let status: String
    let x: Double
    let y: Double
    let zIndex: Int
    let agentType: String
    let workingDirectory: String?
    let mainRepoPath: String?
    let groupId: UUID?
    let isOriginal: Bool
    let createdAt: Date
    let lastActivityAt: Date

    // Messages
    let messages: [PersistedMessage]

    // Completed requests for duplicate detection
    let completedRequests: [String]

    struct PersistedMessage: Codable {
        let role: String
        let content: String
        let timestamp: Date
    }
}

// MARK: - Persisted Canvas State

struct PersistedCanvasState: Codable {
    let projectPath: String
    let lastSaved: Date
    let viewportOffsetX: Double
    let viewportOffsetY: Double
    let viewportScale: Double
    let instances: [PersistedInstance]
    let versionHistory: [VersionEntry]
}

// MARK: - Persistence Service

@MainActor
final class PersistenceService {
    static let shared = PersistenceService()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - File Paths

    /// Gets the persistence file path for a project
    private func persistencePath(for projectPath: String) -> URL {
        let parallelDir = URL(fileURLWithPath: projectPath).appendingPathComponent(".parallel")
        try? fileManager.createDirectory(at: parallelDir, withIntermediateDirectories: true)
        return parallelDir.appendingPathComponent("canvas-state.json")
    }

    private func historyPath(for projectPath: String) -> URL {
        let parallelDir = URL(fileURLWithPath: projectPath).appendingPathComponent(".parallel")
        return parallelDir.appendingPathComponent("version-history.json")
    }

    // MARK: - Save

    /// Saves the current canvas state for a project
    func saveCanvasState(_ canvasState: CanvasState, projectPath: String) {
        let instances = canvasState.instances.map { instance -> PersistedInstance in
            PersistedInstance(
                id: instance.id,
                name: instance.name,
                task: instance.task,
                branchName: instance.branchName,
                status: instance.status.rawValue,
                x: instance.x,
                y: instance.y,
                zIndex: instance.zIndex,
                agentType: instance.agentType.rawValue,
                workingDirectory: instance.workingDirectory,
                mainRepoPath: instance.mainRepoPath,
                groupId: instance.groupId,
                isOriginal: instance.isOriginal,
                createdAt: instance.createdAt,
                lastActivityAt: instance.lastActivityAt,
                messages: instance.messages.map { msg in
                    PersistedInstance.PersistedMessage(
                        role: msg.role == .user ? "user" : "assistant",
                        content: msg.content,
                        timestamp: msg.timestamp
                    )
                },
                completedRequests: instance.completedRequests
            )
        }

        // Load existing history
        let history = loadVersionHistory(for: projectPath)

        let state = PersistedCanvasState(
            projectPath: projectPath,
            lastSaved: Date(),
            viewportOffsetX: canvasState.viewport.offset.x,
            viewportOffsetY: canvasState.viewport.offset.y,
            viewportScale: canvasState.viewport.scale,
            instances: instances,
            versionHistory: history
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(state)
            try data.write(to: persistencePath(for: projectPath))
            print("Saved canvas state to \(persistencePath(for: projectPath))")
        } catch {
            print("Failed to save canvas state: \(error)")
        }
    }

    // MARK: - Load

    /// Loads the canvas state for a project
    func loadCanvasState(for projectPath: String) -> PersistedCanvasState? {
        let path = persistencePath(for: projectPath)
        guard fileManager.fileExists(atPath: path.path) else { return nil }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PersistedCanvasState.self, from: data)
        } catch {
            print("Failed to load canvas state: \(error)")
            return nil
        }
    }

    /// Restores instances from persisted state
    func restoreInstances(from persisted: PersistedCanvasState, to canvasState: CanvasState) {
        for pInstance in persisted.instances {
            let instance = ClaudeInstance(
                id: pInstance.id,
                name: pInstance.name,
                task: pInstance.task,
                x: pInstance.x,
                y: pInstance.y,
                zIndex: pInstance.zIndex
            )

            instance.branchName = pInstance.branchName
            instance.status = InstanceStatus(rawValue: pInstance.status) ?? .idle
            instance.agentType = AgentType(rawValue: pInstance.agentType) ?? .worker
            instance.workingDirectory = pInstance.workingDirectory
            instance.mainRepoPath = pInstance.mainRepoPath
            instance.groupId = pInstance.groupId
            instance.isOriginal = pInstance.isOriginal
            instance.createdAt = pInstance.createdAt
            instance.lastActivityAt = pInstance.lastActivityAt

            // Restore messages
            for pMsg in pInstance.messages {
                let role: ChatMessage.MessageRole = pMsg.role == "user" ? .user : .assistant
                instance.messages.append(ChatMessage(role: role, content: pMsg.content))
            }

            // Restore completed requests
            instance.completedRequests = pInstance.completedRequests

            canvasState.instances.append(instance)
        }

        // Restore viewport
        canvasState.viewport.offset = CGPoint(x: persisted.viewportOffsetX, y: persisted.viewportOffsetY)
        canvasState.viewport.scale = persisted.viewportScale
    }

    // MARK: - Version History

    /// Loads version history for a project
    func loadVersionHistory(for projectPath: String) -> [VersionEntry] {
        let path = historyPath(for: projectPath)
        guard fileManager.fileExists(atPath: path.path) else { return [] }

        do {
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([VersionEntry].self, from: data)
        } catch {
            print("Failed to load version history: \(error)")
            return []
        }
    }

    /// Adds a version entry
    func addVersionEntry(_ entry: VersionEntry, for projectPath: String) {
        var history = loadVersionHistory(for: projectPath)
        history.append(entry)

        // Keep last 100 entries
        if history.count > 100 {
            history = Array(history.suffix(100))
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: historyPath(for: projectPath))
        } catch {
            print("Failed to save version history: \(error)")
        }
    }

    /// Records an agent action to version history
    func recordAction(
        agentId: UUID,
        agentName: String,
        action: String,
        summary: String,
        filesChanged: [String] = [],
        projectPath: String
    ) {
        let entry = VersionEntry(
            agentId: agentId,
            agentName: agentName,
            action: action,
            summary: summary,
            filesChanged: filesChanged
        )
        addVersionEntry(entry, for: projectPath)
    }

    // MARK: - Auto-Save

    /// Sets up auto-save for a canvas state
    func startAutoSave(canvasState: CanvasState, projectPath: String, interval: TimeInterval = 30) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak canvasState] _ in
            guard let state = canvasState else { return }
            Task { @MainActor in
                PersistenceService.shared.saveCanvasState(state, projectPath: projectPath)
            }
        }
    }
}
