//
//  JiraService.swift
//  Parallel
//
//  Mock Jira integration service for ticket creation
//

import Foundation

@MainActor
final class JiraService: ObservableObject {
    static let shared = JiraService()

    private var mockTicketCounter: Int = 1

    private init() {}

    // MARK: - Public Methods

    /// Creates a mock Jira ticket
    func createTicket(
        title: String,
        description: String,
        subtasks: [TaskSpec.Subtask]? = nil
    ) async -> JiraTicket {
        // Simulate network delay
        try? await Task.sleep(for: .milliseconds(500))

        let key = "PROJ-\(mockTicketCounter)"
        mockTicketCounter += 1

        return JiraTicket(
            key: key,
            title: title,
            status: .inProgress,
            url: "https://jira.example.com/browse/\(key)"
        )
    }

    /// Updates a ticket's status (mock)
    func updateTicketStatus(ticketId: UUID, status: JiraTicket.JiraStatus) async {
        // Mock update - in real implementation would call Jira API
        try? await Task.sleep(for: .milliseconds(200))
    }

    /// Creates subtasks for a parent ticket (mock)
    func createSubtasks(
        parentKey: String,
        subtasks: [TaskSpec.Subtask]
    ) async -> [JiraTicket] {
        var tickets: [JiraTicket] = []

        for subtask in subtasks {
            try? await Task.sleep(for: .milliseconds(100))

            let key = "PROJ-\(mockTicketCounter)"
            mockTicketCounter += 1

            tickets.append(JiraTicket(
                key: key,
                title: subtask.title,
                status: .todo,
                url: "https://jira.example.com/browse/\(key)"
            ))
        }

        return tickets
    }
}
