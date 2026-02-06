//
//  ClaudeAPIService.swift
//  Parallel
//
//  Claude API integration for intelligent features
//

import Foundation

@MainActor
final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    // API key loaded from environment variable ANTHROPIC_API_KEY
    private var apiKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }
    private let baseURL = "https://api.anthropic.com/v1/messages"

    private init() {}

    // MARK: - Smart Title Generation

    /// Generates an intelligent, concise title for a task based on the user's message
    func generateSmartTitle(from message: String, context: String? = nil) async -> String? {
        let systemPrompt = """
        You are a title generator. Given a user's task or message, generate a short, clear title (3-7 words max).

        Rules:
        - Be concise and descriptive
        - Use action words (Add, Fix, Update, Create, Implement, etc.)
        - Don't include "please", "can you", etc.
        - Capitalize appropriately (title case)
        - No quotes or punctuation at the end
        - Focus on WHAT is being done, not HOW

        Examples:
        - "please make the background green" → "Change Background to Green"
        - "can you add a login button to the header" → "Add Login Button to Header"
        - "fix the bug where users can't submit the form" → "Fix Form Submission Bug"
        - "i want to implement dark mode" → "Implement Dark Mode"
        - "update the API to return user profiles" → "Add User Profiles to API"

        Respond with ONLY the title, nothing else.
        """

        var userMessage = message
        if let ctx = context, !ctx.isEmpty {
            userMessage = "Context: \(ctx)\n\nTask: \(message)"
        }

        return await sendMessage(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: 30
        )
    }

    /// Generates a summary of what an agent accomplished
    func generateSummary(messages: [ChatMessage], task: String) async -> String? {
        let systemPrompt = """
        You are a summarizer. Given a conversation between a user and an AI coding agent,
        summarize what was accomplished in 1-2 short sentences.

        Focus on:
        - What was built/changed
        - Key files modified
        - The outcome

        Be concise and factual.
        """

        let conversation = messages.map { msg in
            let role = msg.role == .user ? "User" : "Agent"
            return "\(role): \(msg.content)"
        }.joined(separator: "\n")

        let userMessage = """
        Task: \(task)

        Conversation:
        \(conversation)

        Summarize what was accomplished:
        """

        return await sendMessage(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: 100
        )
    }

    // MARK: - Duplicate Request Detection

    /// Checks if a new request is essentially the same as a previous one
    /// Returns true if the request is a duplicate and should be skipped
    func isDuplicateRequest(newRequest: String, previousRequests: [String]) async -> Bool {
        guard !previousRequests.isEmpty else { return false }

        let systemPrompt = """
        You are checking if a new request is essentially asking for the same thing as previous requests.

        Consider two requests the same if:
        - They ask for the same visual/functional change
        - They use different wording but mean the same thing
        - One is a rephrased version of another

        Respond with ONLY "yes" or "no".
        """

        let previousList = previousRequests.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let userMessage = """
        Previous requests:
        \(previousList)

        New request: \(newRequest)

        Is this new request essentially the same as any of the previous requests?
        """

        let response = await sendMessage(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            maxTokens: 10
        )

        return response?.lowercased().contains("yes") ?? false
    }

    /// Generates a response for when a duplicate request is detected
    func generateDuplicateResponse(request: String) async -> String? {
        let systemPrompt = """
        The user asked for something that was already done. Generate a brief, friendly response
        acknowledging that the change was already made. Keep it to 1 sentence.

        Examples:
        - "This change was already made - the background is already dark pink!"
        - "I already implemented that - check the preview to see the dark mode!"
        - "That's already done! The button should be visible in the header."
        """

        return await sendMessage(
            systemPrompt: systemPrompt,
            userMessage: "Request: \(request)",
            maxTokens: 50
        )
    }

    // MARK: - API Request

    private func sendMessage(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = 100,
        model: String = "claude-3-5-haiku-20241022"
    ) async -> String? {
        guard let url = URL(string: baseURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Claude API error: \(String(data: data, encoding: .utf8) ?? "unknown")")
                return nil
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstContent = content.first,
               let text = firstContent["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Claude API request failed: \(error)")
        }

        return nil
    }
}
