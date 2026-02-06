//
//  NestedWorkerCard.swift
//  Parallel
//
//  Compact card view for displaying worker agents nested within coordinator cards
//

import SwiftUI

struct NestedWorkerCard: View {
    let worker: ClaudeInstance
    let editorialInk: Color
    let editorialMeta: Color
    let editorialBorder: Color

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 12) {
                StatusIndicator(status: worker.status)

                VStack(alignment: .leading, spacing: 2) {
                    Text(worker.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(editorialInk)

                    Text(worker.task)
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                        .lineLimit(1)
                }

                Spacer()

                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                // Show worker's details
                VStack(alignment: .leading, spacing: 8) {
                    // Subtask description
                    if let subtask = worker.subtask {
                        Text(subtask)
                            .font(.system(size: 12))
                            .foregroundColor(editorialMeta)
                            .lineLimit(3)
                    }

                    // Current question if any
                    if let question = worker.pendingQuestion {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(DesignColors.statusWaiting)

                            Text(question.question)
                                .font(.system(size: 12))
                                .foregroundColor(editorialInk)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .background(DesignColors.statusWaiting.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Last few messages
                    if !worker.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(worker.messages.suffix(2)) { message in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(message.role == .user ? "You:" : "Agent:")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(editorialMeta)

                                    Text(message.content)
                                        .font(.system(size: 11))
                                        .foregroundColor(editorialInk.opacity(0.8))
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(editorialBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Workers Summary Row

struct WorkersSummaryRow: View {
    let workers: [ClaudeInstance]
    let editorialMeta: Color

    var body: some View {
        HStack(spacing: 16) {
            // Running count
            let runningCount = workers.filter { $0.status == .running }.count
            if runningCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignColors.statusRunning)
                        .frame(width: 8, height: 8)
                    Text("\(runningCount) running")
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                }
            }

            // Waiting count
            let waitingCount = workers.filter { $0.status == .waiting }.count
            if waitingCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignColors.statusWaiting)
                        .frame(width: 8, height: 8)
                    Text("\(waitingCount) waiting")
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                }
            }

            // Completed count
            let completedCount = workers.filter { $0.status == .completed }.count
            if completedCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignColors.statusReady)
                        .frame(width: 8, height: 8)
                    Text("\(completedCount) done")
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Aggregated Question Row

struct AggregatedQuestionRow: View {
    let workerQuestion: WorkerQuestion
    let editorialInk: Color
    let editorialMeta: Color

    @State private var answerText: String = ""
    @FocusState private var isAnswerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Worker attribution
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "#FF9500"))
                    .frame(width: 8, height: 8)

                Text("From \(workerQuestion.workerName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(editorialMeta)

                Spacer()

                Text(timeAgo(workerQuestion.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(editorialMeta)
            }

            // Context if available
            if !workerQuestion.question.context.isEmpty {
                Text(workerQuestion.question.context)
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(editorialMeta)
            }

            // Question text
            Text(workerQuestion.question.question)
                .font(.custom("Georgia", size: 16))
                .foregroundColor(editorialInk)
                .lineSpacing(4)

            // Answer options if provided
            if !workerQuestion.question.options.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(workerQuestion.question.options) { option in
                        HStack(spacing: 8) {
                            Text("→")
                                .font(.system(size: 12))
                                .foregroundColor(editorialMeta)

                            Text(option.label)
                                .font(.system(size: 14))
                                .foregroundColor(editorialInk)

                            if let shortcut = option.shortcut {
                                Text("(\(shortcut))")
                                    .font(.system(size: 12))
                                    .foregroundColor(editorialMeta)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#FF9500").opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#FF9500").opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}

// MARK: - Compact Worker Card (for side panel)

struct CompactWorkerCard: View {
    let worker: ClaudeInstance
    let editorialInk: Color
    let editorialMeta: Color
    let editorialBorder: Color

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            StatusIndicator(status: worker.status)

            VStack(alignment: .leading, spacing: 3) {
                Text(worker.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(editorialInk)

                Text(worker.task)
                    .font(.system(size: 11))
                    .foregroundColor(editorialMeta)
                    .lineLimit(2)
            }

            Spacer()

            // Status badge
            if worker.status == .waiting {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignColors.statusWaiting)
            } else if worker.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignColors.statusReady)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(editorialBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Side Panel Question Card

struct SidePanelQuestionCard: View {
    let workerQuestion: WorkerQuestion
    let editorialInk: Color
    let editorialMeta: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Worker attribution with status
            HStack(spacing: 6) {
                Circle()
                    .fill(DesignColors.statusWaiting)
                    .frame(width: 8, height: 8)

                Text(workerQuestion.workerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(editorialInk)

                Spacer()

                Text(timeAgo(workerQuestion.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(editorialMeta)
            }

            // Question text
            Text(workerQuestion.question.question)
                .font(.system(size: 13))
                .foregroundColor(editorialInk)
                .lineSpacing(3)

            // Options if available
            if !workerQuestion.question.options.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(workerQuestion.question.options) { option in
                        HStack(spacing: 6) {
                            if let shortcut = option.shortcut {
                                Text(shortcut)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(editorialMeta)
                                    .frame(width: 16, height: 16)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }

                            Text(option.label)
                                .font(.system(size: 12))
                                .foregroundColor(editorialInk.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignColors.statusWaiting.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignColors.statusWaiting.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }
}
