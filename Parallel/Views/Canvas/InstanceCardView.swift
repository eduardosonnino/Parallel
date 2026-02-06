//
//  InstanceCardView.swift
//  Parallel
//
//  Card component for Claude instances - renders at full size, scaled down when collapsed
//

import SwiftUI

// MARK: - Instance Card View

struct InstanceCardView: View {
    let instance: ClaudeInstance
    let index: Int
    let isActive: Bool
    let isSelected: Bool
    let currentScale: CGFloat
    let screenSize: CGSize

    @Environment(CanvasState.self) private var canvasState
    @Environment(CanvasCoordinator.self) private var coordinator

    // MARK: - Local State

    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var hasAppeared: Bool = false

    // MARK: - Computed Dimensions

    private var cardWidth: CGFloat {
        LayoutConstants.cardWidth
    }

    private var cardHeight: CGFloat {
        if isActive {
            // When active, fit within screen with margins for top bar and bottom input
            let topMargin: CGFloat = 60
            let bottomMargin: CGFloat = 100  // Space for input box
            return max(screenSize.height - topMargin - bottomMargin, 400)
        }
        return LayoutConstants.cardHeight
    }

    // MARK: - Computed Properties

    private var cardScale: CGFloat {
        if isActive { return 1.0 }
        let baseScale = LayoutConstants.cardBaseScale
        return isSelected ? baseScale * LayoutConstants.selectedScaleMultiplier : baseScale
    }

    private var cornerRadius: CGFloat {
        isActive ? LayoutConstants.cardRadiusZoomed : LayoutConstants.cardRadiusDefault
    }

    private var backgroundColor: Color {
        DesignColors.cardBackground
    }

    private var shadow: ShadowStyle {
        if isActive { return .none }
        if isDragging { return .cardDragging }
        if isSelected { return .cardSelected }
        return .cardDefault
    }

    private var cardOpacity: Double {
        if canvasState.activeCardId != nil && !isActive { return 0 }
        if canvasState.mergingCardId == instance.id { return 0 }  // Fade out when merging
        return 1.0
    }

    private var isMerging: Bool {
        canvasState.mergingCardId == instance.id
    }

    private var mergeScale: CGFloat {
        isMerging ? 0.3 : 1.0  // Shrink when merging
    }

    // MARK: - Body

    @State private var previewExpanded: Bool = false
    @State private var showPreviewPiP: Bool = false  // Delayed appearance for fade-in effect

    var body: some View {
        ZStack {
            // PiP Preview - positioned BEHIND the card, fades in/out in sync with card
            previewPiPOverlay
                .opacity(showPreviewPiP ? 1 : 0)
                .scaleEffect(showPreviewPiP ? 1 : 0.7)
                .offset(x: showPreviewPiP ? 0 : -30, y: showPreviewPiP ? 0 : 30)
                .animation(CanvasAnimations.mainTransition, value: showPreviewPiP)
                .zIndex(0)
                .allowsHitTesting(isActive && showPreviewPiP)

            // Main card layout
            HStack(alignment: .top, spacing: 24) {
                // Left editorial panel - Spec & Jira (no background)
                if isActive && instance.agentType == .coordinator {
                    specSidePanel
                        .frame(width: 280)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                // Main card
                ZStack {
                    cardContainer
                        .frame(width: cardWidth, height: cardHeight)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(backgroundColor)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay(selectionStrokeOverlay)
                        .applyShadow(shadow)
                        .overlay(waitingIndicatorOverlay)
                }
                .overlay(closeButtonOverlay)

                // Right spacer for balance (no panel - questions are in main thread now)
                if isActive && instance.agentType == .coordinator {
                    Color.clear
                        .frame(width: 280)
                }
            }
            .scaleEffect(cardScale * mergeScale)
            .opacity(hasAppeared ? cardOpacity : 0)
            .scaleEffect(hasAppeared ? 1 : LayoutConstants.entryScale)
            .offset(dragOffset)
            .gesture(dragGesture)
            .onTapGesture(perform: handleTap)
            // Disable all animations during drag for instant response
            .transaction { transaction in
                if isDragging {
                    transaction.animation = nil
                }
            }
            .animation(isDragging ? nil : CanvasAnimations.mainTransition, value: isActive)
            .animation(isDragging ? nil : CanvasAnimations.mainTransition, value: cardScale)
            .animation(isDragging ? nil : CanvasAnimations.mainTransition, value: cornerRadius)
            .animation(isDragging ? nil : CanvasAnimations.cardOpacity, value: cardOpacity)
            .animation(isDragging ? nil : CanvasAnimations.boxShadow, value: shadow)
            .animation(isDragging ? nil : CanvasAnimations.mainTransition, value: isSelected)
            .animation(.easeInOut(duration: 0.6), value: isMerging)
            .animation(.easeInOut(duration: 0.6), value: mergeScale)
            .zIndex(1)
        }
        .onAppear {
            withAnimation(CanvasAnimations.staggeredEntry(index: index)) {
                hasAppeared = true
            }
        }
        .onChange(of: isActive) { _, newValue in
            // Animate preview in sync with card - slight delay on expand for "from behind" effect
            if newValue {
                // Small delay so card starts expanding first, then preview emerges
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showPreviewPiP = true
                }
            } else {
                // On collapse, animate preview back under immediately
                showPreviewPiP = false
            }
        }
    }

    // MARK: - Preview PiP Overlay

    @ViewBuilder
    private var previewPiPOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                if previewExpanded {
                    // Fullscreen preview
                    ExpandedPreviewView(
                        instance: instance,
                        screenSize: screenSize,
                        onClose: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                previewExpanded = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(100)
                } else {
                    // Mini PiP in bottom right - emerges from behind
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MiniPreviewPiP(
                                instance: instance,
                                onTap: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        previewExpanded = true
                                    }
                                }
                            )
                            .shadow(color: .black.opacity(0.4), radius: 20, x: -5, y: -5)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Scroll State

    @State private var scrollOffset: CGFloat = 0
    @State private var headerBottomY: CGFloat = 0
    @State private var cardTopY: CGFloat = 0

    // MARK: - Card Container (Unified for smooth zoom)

    private var cardContainer: some View {
        ZStack(alignment: .top) {
            // Always use regular layout - coordinator panels are now outside the card
            regularCardLayout

            // Sticky header overlay (fades in/out based on scroll position)
            if isActive {
                stickyHeaderOverlay
                    .opacity(showStickyHeader ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: showStickyHeader)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CardTopKey.self,
                    value: geo.frame(in: .global).minY
                )
            }
        )
        .onPreferenceChange(CardTopKey.self) { value in
            cardTopY = value
        }
    }

    // MARK: - Spec Side Panel (Editorial style - no background)

    private var specSidePanel: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Jira ticket section
            if let ticket = instance.jiraTicket {
                VStack(alignment: .leading, spacing: 12) {
                    Text("TICKET")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(editorialMeta)

                    HStack(spacing: 8) {
                        Text(ticket.key)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(editorialInk)

                        Text("·")
                            .foregroundColor(editorialMeta)

                        Text(ticket.status.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(editorialMeta)
                    }
                }
            }

            // Spec section
            if let spec = instance.spec {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SPECIFICATION")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(editorialMeta)

                    Text(spec.description)
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(editorialInk.opacity(0.9))
                        .lineSpacing(6)

                    // Subtasks
                    if !spec.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(spec.subtasks) { subtask in
                                HStack(alignment: .top, spacing: 10) {
                                    // Find worker for this subtask
                                    let worker = workerInstances.first { $0.subtask == subtask.description }

                                    Circle()
                                        .fill(worker?.status.color ?? editorialMeta)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 6)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subtask.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(editorialInk)

                                        if let worker = worker {
                                            Text(worker.status.displayName)
                                                .font(.system(size: 11))
                                                .foregroundColor(editorialMeta)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            } else if instance.status == .specifying {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SPECIFICATION")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(editorialMeta)

                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(editorialMeta)

                        Text("Writing spec...")
                            .font(.custom("Georgia", size: 15))
                            .italic()
                            .foregroundColor(editorialMeta)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 48)
        .padding(.horizontal, 24)
    }

    // MARK: - Regular Card Layout (Non-coordinator or collapsed)

    private var regularCardLayout: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: isActive) {
                VStack(alignment: .leading, spacing: 24) {
                    // Track scroll position using background
                    Color.clear
                        .frame(height: 1)
                        .id("scrollTop")
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .global).minY
                                )
                            }
                        )

                    // Unified header content
                    unifiedHeader

                    // Collapsed state: show question prominently
                    if !isActive, let question = instance.pendingQuestion {
                        pendingQuestionView(question)
                    }

                    // Expanded state: show chat with question in thread
                    if isActive {
                        chatView

                        // Show terminal when agent is running
                        if instance.status.isActive {
                            terminalSection
                        }

                        // Anchor for scrolling to bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 64)
                .padding(.top, 48)
                .padding(.bottom, 64)
            }
            .scrollDisabled(!isActive)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .onChange(of: instance.messages.count) { _, _ in
                if isActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: instance.pendingQuestion?.id) { _, _ in
                if isActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var showStickyHeader: Bool {
        // Show sticky header when the header's bottom edge has scrolled above the card's top
        headerBottomY < cardTopY
    }

    // MARK: - Unified Header (same content, transforms based on state)

    private var unifiedHeader: some View {
        VStack(alignment: .leading, spacing: isActive ? 24 : 24) {
            // Meta label with status
            HStack(spacing: 8) {
                StatusIndicator(status: instance.status)
                Text(instance.status.displayName.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(editorialMeta)

                // Coordinator badge
                if instance.agentType == .coordinator {
                    coordinatorBadge
                }

                Spacer()

                // Jira ticket badge
                if let ticket = instance.jiraTicket {
                    jiraTicketBadge(ticket)
                }

                Text(instance.shortBranchName)
                    .font(Typography.monospaceSmall)
                    .foregroundColor(editorialMeta)
            }

            // Title - same in both states
            Text(instance.task.isEmpty ? instance.displayName : instance.task)
                .font(Typography.cardTitle)
                .foregroundColor(editorialInk)
                .lineLimit(isActive ? nil : 3)
                .frame(minHeight: isActive ? nil : 80, alignment: .topLeading)

            // Agent byline with worker avatars
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("by")
                        .font(.custom("Georgia", size: 16))
                        .italic()
                        .foregroundColor(editorialMeta)
                    Text(instance.displayName)
                        .font(.custom("Georgia", size: 16))
                        .italic()
                        .foregroundColor(editorialInk)
                }

                // Worker avatars (for coordinators with workers)
                if instance.agentType == .coordinator && !workerInstances.isEmpty {
                    workerAvatars
                }
            }
        }
        .padding(.bottom, isActive ? 24 : 0)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1)
                .opacity(isActive ? 1 : 0),
            alignment: .bottom
        )
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeaderBottomKey.self,
                    value: geo.frame(in: .global).maxY
                )
            }
        )
        .onPreferenceChange(HeaderBottomKey.self) { value in
            headerBottomY = value
        }
    }

    // MARK: - Sticky Header Overlay (appears when scrolling)

    private var stickyHeaderOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                StatusIndicator(status: instance.status)

                Text(instance.task.isEmpty ? instance.displayName : instance.task)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(editorialInk)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Text("by")
                        .font(.custom("Georgia", size: 13))
                        .italic()
                        .foregroundColor(editorialMeta)
                    Text(instance.displayName)
                        .font(.custom("Georgia", size: 13))
                        .italic()
                        .foregroundColor(editorialInk)
                }
            }
            .padding(.horizontal, 64)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(DesignColors.cardBackground)

            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1)

            Spacer()
        }
    }


    // MARK: - Editorial Colors (Dark Theme)

    private let editorialBackground = DesignColors.cardBackground
    private let editorialInk = Color.white
    private let editorialMeta = Color.white.opacity(0.5)
    private let editorialBorder = Color.white.opacity(0.1)

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack {
            HStack(spacing: 8) {
                StatusIndicator(status: instance.status)
                Text(instance.status.displayName)
                    .font(Typography.body)
                    .foregroundColor(DesignColors.textSecondary)
            }

            Spacer()

            Text(instance.shortBranchName)
                .font(Typography.monospaceSmall)
                .foregroundColor(DesignColors.textSecondary)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        Text(instance.task.isEmpty ? instance.displayName : instance.task)
            .font(Typography.cardTitle)
            .foregroundColor(DesignColors.textPrimary)
            .lineLimit(isActive ? nil : 3)
            .frame(minHeight: 80, alignment: .topLeading)
    }

    // MARK: - Agent Section

    private var agentSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#D4A574"))

            Text(instance.displayName)
                .font(Typography.bodyLarge)
                .foregroundColor(DesignColors.textSecondary)
        }
        .frame(minHeight: 40, alignment: .topLeading)
    }

    // MARK: - Pending Question View (Collapsed State)

    // MARK: - Pending Question View (Editorial Style - used in collapsed state)

    private func pendingQuestionView(_ question: PendingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question label
            Text("WAITING FOR INPUT")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(editorialMeta)

            // Context if available
            if !question.context.isEmpty {
                Text(question.context)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(editorialMeta)
                    .lineSpacing(4)
                    .lineLimit(3)
            }

            // Question text
            Text(question.question)
                .font(.custom("Georgia", size: 17))
                .foregroundColor(editorialInk)
                .lineSpacing(6)
                .lineLimit(4)

            // Answer options as link rows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(question.options) { option in
                    Button(action: {
                        instance.answerQuestion(with: option)
                    }) {
                        EditorialLinkRow(
                            arrow: "→",
                            title: option.label,
                            shortcut: option.shortcut
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(.top, 16)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Chat View (Editorial Style)

    private var chatView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("CONVERSATION")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.5)
                .foregroundColor(editorialMeta)
                .padding(.top, 24)
                .padding(.bottom, 24)

            if instance.messages.isEmpty && instance.pendingQuestion == nil && instance.pendingWorkerQuestions.isEmpty {
                // Empty state
                Text("Send a message to begin the conversation with this agent.")
                    .font(.custom("Georgia", size: 17))
                    .foregroundColor(editorialMeta)
                    .lineSpacing(6)
                    .padding(.bottom, 24)
            } else {
                // Messages list - editorial style
                ForEach(instance.messages) { message in
                    EditorialMessageView(message: message)
                }

                // Worker questions (for coordinators) - in main thread with attribution
                if instance.agentType == .coordinator {
                    let unansweredQuestions = instance.pendingWorkerQuestions.filter { !$0.answered }
                    ForEach(unansweredQuestions) { workerQuestion in
                        workerQuestionView(workerQuestion)
                    }
                }

                // Pending question at the end of the thread (for direct questions)
                if let question = instance.pendingQuestion {
                    editorialQuestionView(question)
                }
            }
        }
    }

    // MARK: - Terminal Section

    @State private var showTerminal: Bool = true

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header with toggle
            HStack {
                Text("TERMINAL")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(editorialMeta)

                Spacer()

                Button(action: { showTerminal.toggle() }) {
                    Image(systemName: showTerminal ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(editorialMeta)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)

            if showTerminal {
                CompactTerminalView(instance: instance)
                    .frame(height: 250)
            }
        }
    }

    // MARK: - Worker Question View (in chat thread with attribution)

    private func workerQuestionView(_ workerQuestion: WorkerQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Worker attribution header
            HStack(spacing: 8) {
                // Worker avatar
                if let worker = canvasState.instance(for: workerQuestion.workerId) {
                    WorkerAvatar(worker: worker)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(workerQuestion.workerName.uppercased())
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(editorialMeta)

                    Text("needs your input")
                        .font(.custom("Georgia", size: 13))
                        .italic()
                        .foregroundColor(editorialMeta)
                }

                Spacer()

                Text(timeAgo(workerQuestion.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(editorialMeta)
            }
            .padding(.top, 16)

            // Context if available
            if !workerQuestion.question.context.isEmpty {
                Text(workerQuestion.question.context)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(editorialMeta)
                    .lineSpacing(4)
            }

            // Question text
            Text(workerQuestion.question.question)
                .font(.custom("Georgia", size: 17))
                .foregroundColor(editorialInk)
                .lineSpacing(6)

            // Answer options as link rows
            if !workerQuestion.question.options.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(workerQuestion.question.options) { option in
                        Button(action: {
                            answerWorkerQuestion(workerQuestion, with: option)
                        }) {
                            EditorialLinkRow(
                                arrow: "→",
                                title: option.label,
                                shortcut: option.shortcut
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func answerWorkerQuestion(_ workerQuestion: WorkerQuestion, with option: PendingQuestion.QuestionOption) {
        // Send answer directly to the Claude process
        ClaudeCodeRunner.shared.sendInput(to: workerQuestion.workerId, input: option.label)

        // Mark question as answered
        if let index = instance.pendingWorkerQuestions.firstIndex(where: { $0.id == workerQuestion.id }) {
            instance.pendingWorkerQuestions[index].answered = true
            instance.pendingWorkerQuestions[index].answer = option.label
        }
    }

    // MARK: - Editorial Question View (in chat thread)

    private func editorialQuestionView(_ question: PendingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question label
            Text("AGENT")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(editorialMeta)
                .padding(.top, 16)

            // Context if available
            if !question.context.isEmpty {
                Text(question.context)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(editorialMeta)
                    .lineSpacing(4)
            }

            // Question text
            Text(question.question)
                .font(.custom("Georgia", size: 17))
                .foregroundColor(editorialInk)
                .lineSpacing(6)

            // Answer options as link rows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(question.options) { option in
                    Button(action: {
                        instance.answerQuestion(with: option)
                    }) {
                        EditorialLinkRow(
                            arrow: "→",
                            title: option.label,
                            shortcut: option.shortcut
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 16)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Inline Question View (Expanded State - part of chat thread)

    private func inlineQuestionView(_ question: PendingQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question as assistant message style
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // Context if available
                    if !question.context.isEmpty {
                        Text(question.context)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Question text
                    Text(question.question)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.1))
                )

                Spacer(minLength: 60)
            }

            // Answer options as buttons
            VStack(spacing: 8) {
                ForEach(question.options) { option in
                    Button(action: {
                        instance.answerQuestion(with: option)
                    }) {
                        HStack {
                            if let shortcut = option.shortcut {
                                Text(shortcut)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 20, height: 20)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            Text(option.label)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(DesignColors.statusWaiting.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(DesignColors.statusWaiting.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Worker Avatars

    private var workerAvatars: some View {
        HStack(spacing: -6) {
            ForEach(Array(workerInstances.prefix(5).enumerated()), id: \.element.id) { index, worker in
                WorkerAvatar(worker: worker)
                    .zIndex(Double(5 - index))
            }

            // Overflow indicator
            if workerInstances.count > 5 {
                Text("+\(workerInstances.count - 5)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(editorialMeta)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
    }

    // MARK: - Coordinator Badge

    private var coordinatorBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 9))
            Text("COORDINATOR")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.3)
        }
        .foregroundColor(Color(hex: "#AF52DE"))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: "#AF52DE").opacity(0.2))
        .clipShape(Capsule())
    }

    // MARK: - Jira Ticket Badge

    private func jiraTicketBadge(_ ticket: JiraTicket) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "ticket")
                .font(.system(size: 9))
            Text(ticket.key)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundColor(Color(hex: "#2684FF"))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: "#2684FF").opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Aggregated Questions Section

    @State private var workersExpanded: Bool = true

    @ViewBuilder
    private var aggregatedQuestionsSection: some View {
        let unansweredQuestions = instance.pendingWorkerQuestions.filter { !$0.answered }

        if !unansweredQuestions.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("QUESTIONS FROM WORKERS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(editorialMeta)
                    .padding(.top, 24)

                ForEach(unansweredQuestions) { workerQuestion in
                    AggregatedQuestionRow(
                        workerQuestion: workerQuestion,
                        editorialInk: editorialInk,
                        editorialMeta: editorialMeta
                    )
                }
            }
        }
    }

    // MARK: - Nested Workers Section

    private var workerInstances: [ClaudeInstance] {
        canvasState.workers(for: instance.id)
    }

    @ViewBuilder
    private var nestedWorkersSection: some View {
        if !instance.workerIds.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                // Section header with toggle
                HStack {
                    Text("WORKERS (\(instance.workerIds.count))")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(editorialMeta)

                    Spacer()

                    Button(action: { workersExpanded.toggle() }) {
                        Image(systemName: workersExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(editorialMeta)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)

                if workersExpanded {
                    ForEach(workerInstances) { worker in
                        NestedWorkerCard(
                            worker: worker,
                            editorialInk: editorialInk,
                            editorialMeta: editorialMeta,
                            editorialBorder: editorialBorder
                        )
                    }
                } else {
                    // Collapsed summary
                    WorkersSummaryRow(
                        workers: workerInstances,
                        editorialMeta: editorialMeta
                    )
                }
            }
        }
    }

    // MARK: - Waiting Indicator Overlay

    @State private var waitingPulse: Bool = false
    @State private var waitingBounce: Bool = false
    @State private var ringExpand: Bool = false

    @ViewBuilder
    private var waitingIndicatorOverlay: some View {
        if instance.status == .waiting {
            ZStack {
                // Animated expanding rings (radar effect) for collapsed cards
                if !isActive {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: cornerRadius + 10, style: .continuous)
                            .stroke(DesignColors.statusWaiting, lineWidth: 2)
                            .scaleEffect(ringExpand ? 1.15 + CGFloat(index) * 0.05 : 1.0)
                            .opacity(ringExpand ? 0 : 0.6 - Double(index) * 0.15)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: ringExpand
                            )
                    }
                }

                // Pulsing border - thicker and more prominent
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        DesignColors.statusWaiting,
                        lineWidth: isActive ? (waitingPulse ? 4 : 2) : (waitingPulse ? 6 : 3)
                    )
                    .opacity(waitingPulse ? 1.0 : 0.5)

                // Strong glow effect
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignColors.statusWaiting, lineWidth: isActive ? 6 : 12)
                    .blur(radius: isActive ? 8 : 16)
                    .opacity(waitingPulse ? 0.8 : 0.3)

                // Extra outer glow for collapsed cards
                if !isActive {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .stroke(DesignColors.statusWaiting, lineWidth: 20)
                        .blur(radius: 24)
                        .opacity(waitingPulse ? 0.5 : 0.15)
                }

                if isActive {
                    // Expanded: animated badge at top right
                    VStack {
                        HStack {
                            Spacer()
                            waitingBadgeAnimated
                                .padding(16)
                        }
                        Spacer()
                    }
                } else {
                    // Collapsed: large animated centered overlay
                    collapsedWaitingOverlay
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                startWaitingAnimations()
            }
            .onDisappear {
                stopWaitingAnimations()
            }
        }
    }

    private var collapsedWaitingOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                // Animated icon with bounce
                ZStack {
                    // Glow behind icon
                    Circle()
                        .fill(DesignColors.statusWaiting)
                        .frame(width: 60, height: 60)
                        .blur(radius: 20)
                        .opacity(waitingPulse ? 0.8 : 0.4)

                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 44))
                        .foregroundColor(DesignColors.statusWaiting)
                        .shadow(color: DesignColors.statusWaiting, radius: 12)
                        .scaleEffect(waitingBounce ? 1.15 : 1.0)
                        .rotationEffect(.degrees(waitingBounce ? -5 : 5))
                }

                Text("NEEDS INPUT")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1)
                    .foregroundColor(.white)

                Text("Click to respond")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignColors.statusWaiting, lineWidth: 3)
                    )
                    .shadow(color: DesignColors.statusWaiting.opacity(0.5), radius: 20)
            )
            .scaleEffect(waitingPulse ? 1.02 : 0.98)

            Spacer()
        }
    }

    private var waitingBadgeAnimated: some View {
        HStack(spacing: 8) {
            // Animated dot
            Circle()
                .fill(DesignColors.statusWaiting)
                .frame(width: 10, height: 10)
                .scaleEffect(waitingPulse ? 1.3 : 0.8)
                .shadow(color: DesignColors.statusWaiting, radius: 4)

            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 14))
                .scaleEffect(waitingBounce ? 1.1 : 1.0)

            Text("NEEDS INPUT")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(DesignColors.statusWaiting)
                .shadow(color: DesignColors.statusWaiting.opacity(0.6), radius: 8)
        )
        .scaleEffect(waitingPulse ? 1.05 : 1.0)
    }

    private func startWaitingAnimations() {
        // Main pulse animation
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            waitingPulse = true
        }
        // Bounce animation (faster)
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            waitingBounce = true
        }
        // Ring expansion
        withAnimation(.linear(duration: 0.01)) {
            ringExpand = true
        }
    }

    private func stopWaitingAnimations() {
        waitingPulse = false
        waitingBounce = false
        ringExpand = false
    }

    // MARK: - Selection Stroke Overlay

    @ViewBuilder
    private var selectionStrokeOverlay: some View {
        if isSelected && !isActive {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
        }
    }

    // MARK: - Close Button

    @ViewBuilder
    private var closeButtonOverlay: some View {
        if isActive {
            VStack {
                HStack {
                    Spacer()
                    Button(action: closeCard) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                }
                Spacer()
            }
        }
    }

    private func closeCard() {
        withAnimation(CanvasAnimations.mainTransition) {
            canvasState.closeZoomedCard()
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: LayoutConstants.minDragDistance, coordinateSpace: .global)
            .onChanged { value in
                guard !isActive else { return }

                if !isDragging {
                    isDragging = true
                    coordinator.startDrag(for: instance.id)
                    canvasState.bringToFront(instance.id)
                }

                // Use global coordinate space for smooth 1:1 tracking
                // Divide by canvas scale to convert screen pixels to canvas units
                let scale = currentScale
                dragOffset = CGSize(
                    width: value.translation.width / scale,
                    height: value.translation.height / scale
                )
            }
            .onEnded { value in
                guard isDragging else { return }

                // Calculate final delta
                let scale = currentScale
                let canvasDelta = CGSize(
                    width: value.translation.width / scale,
                    height: value.translation.height / scale
                )

                // Use withTransaction to disable ALL animations during the update
                // This prevents the visual snap-back
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    // Update the instance position directly (adding the delta)
                    instance.x += canvasDelta.width
                    instance.y += canvasDelta.height

                    // Update organic position if needed
                    if canvasState.viewMode == .organic {
                        instance.organicX = instance.x
                        instance.organicY = instance.y
                    }

                    // Reset dragOffset after position is updated
                    dragOffset = .zero
                }

                // Clean up coordinator state (keep isDraggingSelection true until after update)
                DispatchQueue.main.async {
                    coordinator.endDrag(for: instance.id, finalDelta: .zero)
                    isDragging = false
                }
            }
    }

    // MARK: - Tap Handler

    private func handleTap() {
        if isActive { return }

        let modifiers = NSEvent.modifierFlags

        if modifiers.contains(.command) {
            withAnimation(CanvasAnimations.mainTransition) {
                canvasState.toggleSelection(instance.id)
            }
        } else if modifiers.contains(.shift) {
            withAnimation(CanvasAnimations.mainTransition) {
                canvasState.addToSelection(instance.id)
            }
        } else {
            withAnimation(CanvasAnimations.mainTransition) {
                canvasState.zoomToCard(instance.id)
            }
        }
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Header Bottom Preference Key

struct HeaderBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Card Top Preference Key

struct CardTopKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: InstanceStatus

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: status.color.opacity(0.5), radius: 4, x: 0, y: 0)
    }
}

// MARK: - Chat Bubble View (for collapsed card - dark theme)

struct ChatBubbleView: View {
    let message: ChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? Color(hex: "#007AFF") : Color.white.opacity(0.1))
                    )

                Text(timeAgo(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
            }

            if !isUser { Spacer(minLength: 60) }
        }
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

// MARK: - Editorial Message View (for expanded card - dark theme)

struct EditorialMessageView: View {
    let message: ChatMessage

    private let editorialInk = Color.white
    private let editorialMeta = Color.white.opacity(0.5)
    private let editorialBorder = Color.white.opacity(0.1)

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Role label
            Text(isUser ? "YOU" : "AGENT")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(editorialMeta)

            // Message content
            Text(message.content)
                .font(.custom("Georgia", size: 17))
                .foregroundColor(editorialInk)
                .lineSpacing(6)

            // Timestamp
            Text(timeAgo(message.timestamp))
                .font(.system(size: 11))
                .foregroundColor(editorialMeta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1),
            alignment: .bottom
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

// MARK: - Editorial Link Row

struct EditorialLinkRow: View {
    let arrow: String
    let title: String
    let shortcut: String?

    private let editorialInk = Color.white
    private let editorialMeta = Color.white.opacity(0.5)
    private let editorialBorder = Color.white.opacity(0.1)
    private let editorialAccent = Color(hex: "#FF6B5B")

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(arrow)
                .font(.system(size: 12))
                .foregroundColor(editorialMeta)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isHovered ? editorialAccent : editorialInk)

            if let shortcut = shortcut {
                Text("(\(shortcut))")
                    .font(.custom("Georgia", size: 13))
                    .italic()
                    .foregroundColor(editorialMeta)
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.leading, isHovered ? 8 : 0)
        .overlay(
            Rectangle()
                .fill(editorialBorder)
                .frame(height: 1),
            alignment: .bottom
        )
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Worker Avatar

struct WorkerAvatar: View {
    let worker: ClaudeInstance

    // Color palette for worker avatars
    private static let avatarColors: [Color] = [
        Color(hex: "#FF6B6B"),  // Coral
        Color(hex: "#4ECDC4"),  // Teal
        Color(hex: "#45B7D1"),  // Sky blue
        Color(hex: "#96CEB4"),  // Sage
        Color(hex: "#FFEAA7"),  // Butter
        Color(hex: "#DDA0DD"),  // Plum
        Color(hex: "#98D8C8"),  // Mint
        Color(hex: "#F7DC6F"),  // Gold
        Color(hex: "#BB8FCE"),  // Lavender
        Color(hex: "#85C1E9"),  // Light blue
    ]

    private var avatarColor: Color {
        // Consistent color based on name hash
        let hash = abs(worker.name.hashValue)
        return Self.avatarColors[hash % Self.avatarColors.count]
    }

    private var initials: String {
        let parts = worker.name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(worker.name.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor)

            Text(initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)

            // Status ring
            Circle()
                .stroke(worker.status.color, lineWidth: 2)
        }
        .frame(width: 24, height: 24)
        .overlay(
            Circle()
                .stroke(Color.black, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let instance = ClaudeInstance.create(
        name: "Atlas",
        task: "Implementing user authentication flow with OAuth2 and JWT tokens",
        at: .zero
    )
    instance.status = .running

    return InstanceCardView(
        instance: instance,
        index: 0,
        isActive: false,
        isSelected: false,
        currentScale: 1.0,
        screenSize: CGSize(width: 1200, height: 800)
    )
    .environment(CanvasState())
    .environment(CanvasCoordinator())
    .environment(CoordinatorService())
    .frame(width: 400, height: 600)
}
