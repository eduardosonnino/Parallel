//
//  ContentView.swift
//  Parallel
//
//  Main content view with canvas and toolbar
//

import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(CanvasState.self) private var canvasState
    @Environment(CanvasCoordinator.self) private var coordinator
    @Environment(CoordinatorService.self) private var coordinatorService
    @Environment(\.currentProject) private var currentProject

    @FocusState private var isFocused: Bool
    @State private var hasStartedServer: Bool = false
    @State private var hasLoadedState: Bool = false
    @State private var showCompareView: Bool = false
    @State private var compareInstanceId: UUID? = nil
    @State private var compareSecondInstanceId: UUID? = nil  // For two-agent comparison

    var body: some View {
        ZStack {
            // Full-screen background
            (canvasState.activeCardId != nil ? DesignColors.cardBackground : DesignColors.canvasBackground)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: canvasState.activeCardId != nil)

            // Main canvas
            ZoomableCanvas()

            // Header overlay (hidden when card is expanded)
            if canvasState.activeCardId == nil {
                VStack {
                    headerView
                    Spacer()
                }
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Bottom bar - either input box or selection toolbar
            VStack {
                Spacer()
                if canvasState.hasSelection && canvasState.activeCardId == nil {
                    selectionToolbar
                        .padding(.bottom, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    inputBoxView
                        .padding(.bottom, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: canvasState.hasSelection)

            // Compare view overlay
            if showCompareView, let instanceId = compareInstanceId {
                GeometryReader { geo in
                    if let secondId = compareSecondInstanceId {
                        // Two-agent comparison
                        TwoAgentCompareView(
                            firstInstanceId: instanceId,
                            secondInstanceId: secondId,
                            screenSize: geo.size,
                            onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showCompareView = false
                                    compareSecondInstanceId = nil
                                }
                            }
                        )
                    } else {
                        // Compare with main
                        ComparePreviewView(
                            instanceId: instanceId,
                            screenSize: geo.size,
                            onClose: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showCompareView = false
                                }
                            }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(1000)
            }

            // Merge success toast
            if showMergeSuccess {
                mergeSuccessToast
                    .zIndex(2000)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: canvasState.activeCardId)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape) {
            if canvasState.activeCardId != nil {
                withAnimation(CanvasAnimations.mainTransition) {
                    canvasState.closeZoomedCard()
                }
                return .handled
            }
            return .ignored
        }
        .onAppear {
            isFocused = true
            startServerIfNeeded()
            loadPersistedStateIfNeeded()
        }
        .onDisappear {
            saveCanvasState()
            stopServer()
        }
        .onChange(of: canvasState.activeCardId) { _, newValue in
            isFocused = true
            updateWindowBackground(isCardExpanded: newValue != nil)
        }
        .background(
            WindowAccessor { window in
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.toolbar = nil
                window.styleMask.insert(.fullSizeContentView)
                window.backgroundColor = NSColor(hex: "#151618")
                window.isOpaque = true
                window.hasShadow = true
                window.isMovableByWindowBackground = false
            }
        )
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Parallel")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())

            Spacer()

            // Project name
            if let project = currentProject {
                Text(project.name)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Selection Toolbar

    @State private var isMerging: Bool = false
    @State private var showMergeSuccess: Bool = false
    @State private var mergeMessage: String = ""

    private var selectionToolbar: some View {
        HStack(spacing: 8) {
            // Selection count badge
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text("\(canvasState.selectionCount) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())

            Spacer()

            // Action buttons
            HStack(spacing: 2) {
                // Merge to main (single selection only)
                if canvasState.selectionCount == 1 {
                    ToolbarButton(
                        icon: "arrow.triangle.merge",
                        label: "Merge",
                        color: Color(red: 0.2, green: 0.8, blue: 0.4),
                        action: mergeToMain
                    )
                    .disabled(isMerging)
                }

                // Compare with source of truth (1 selected) or compare two agents (2 selected)
                if canvasState.selectionCount == 1 {
                    ToolbarButton(
                        icon: "rectangle.split.2x1",
                        label: "Compare",
                        color: Color(red: 0.4, green: 0.6, blue: 1.0),
                        action: compareWithMain
                    )
                } else if canvasState.selectionCount == 2 {
                    ToolbarButton(
                        icon: "rectangle.split.2x1",
                        label: "Compare Agents",
                        color: Color(red: 0.4, green: 0.6, blue: 1.0),
                        action: compareTwoAgents
                    )
                }

                // Divider
                if canvasState.selectionCount <= 2 {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 6)
                }

                // Remix
                ToolbarButton(
                    icon: "arrow.triangle.branch",
                    label: "Remix",
                    color: Color(red: 0.7, green: 0.5, blue: 1.0),
                    action: remixSelected
                )

                // Delete
                ToolbarButton(
                    icon: "trash",
                    label: "Delete",
                    color: Color(red: 1.0, green: 0.4, blue: 0.4),
                    action: deleteSelected
                )
            }

            // Close button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    canvasState.clearSelection()
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.8)

                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .frame(maxWidth: 560)
        .padding(.horizontal, 40)
    }

    private func deleteSelected() {
        withAnimation {
            for id in canvasState.selectedIds {
                ServerManager.shared.releasePort(for: id)
            }
            coordinator.deleteSelected()
        }
    }

    private func remixSelected() {
        guard let selectedId = canvasState.selectedIds.first,
              let instance = canvasState.instance(for: selectedId) else { return }

        // Create or get group ID
        let groupId = instance.groupId ?? UUID()

        // If original doesn't have a group, assign it
        if instance.groupId == nil {
            instance.groupId = groupId
            instance.isOriginal = true
        }

        // Create remix card - positioned slightly offset for stack effect
        let existingInGroup = canvasState.instancesInGroup(groupId).count
        let offsetX: Double = 15 * Double(existingInGroup)
        let offsetY: Double = 15 * Double(existingInGroup)

        let remix = ClaudeInstance.create(
            name: "\(instance.name) remix",
            task: instance.task,
            at: CGPoint(x: instance.x + offsetX, y: instance.y + offsetY)
        )
        remix.groupId = groupId
        remix.isOriginal = false
        remix.mainRepoPath = instance.mainRepoPath ?? currentProject?.path
        remix.agentType = .coordinator
        remix.status = .idle

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            canvasState.addInstance(remix)
        }

        // Copy code from original's isolated directory to new isolated directory
        if let sourceDir = instance.workingDirectory {
            Task {
                await coordinatorService.startRemix(remix, copyingFrom: sourceDir)
            }
        }

        // Clear selection
        withAnimation {
            canvasState.clearSelection()
        }
    }

    private func compareWithMain() {
        guard let selectedId = canvasState.selectedIds.first else { return }
        compareInstanceId = selectedId
        compareSecondInstanceId = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showCompareView = true
        }
    }

    private func compareTwoAgents() {
        let selectedArray = Array(canvasState.selectedIds)
        guard selectedArray.count == 2 else { return }
        compareInstanceId = selectedArray[0]
        compareSecondInstanceId = selectedArray[1]
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showCompareView = true
        }
    }

    private func mergeToMain() {
        guard let selectedId = canvasState.selectedIds.first,
              let instance = canvasState.instance(for: selectedId) else { return }

        isMerging = true

        // Get working directory
        let workDir = instance.workingDirectory ?? instance.mainRepoPath ?? currentProject?.path

        guard let workingDirectory = workDir else {
            isMerging = false
            return
        }

        let branchName = instance.branchName

        Task {
            do {
                // Perform the git merge
                try await GitService.shared.mergeBranch(
                    branchName,
                    into: "main",
                    workingDirectory: workingDirectory
                )

                await MainActor.run {
                    // Update instance status
                    instance.status = .merged
                    mergeMessage = "\(instance.shortBranchName) → main"

                    // Record merge to version history
                    if let projectPath = currentProject?.path {
                        PersistenceService.shared.recordAction(
                            agentId: instance.id,
                            agentName: instance.displayName,
                            action: "merged",
                            summary: "Merged branch \(instance.branchName) into main",
                            filesChanged: [],
                            projectPath: projectPath
                        )
                    }

                    // Clear selection immediately
                    canvasState.clearSelection()

                    // Phase 1: Start the swallowing animation - card moves toward main (left side) and shrinks
                    withAnimation(.easeInOut(duration: 0.7)) {
                        // Set merging state to trigger scale/opacity animation in card view
                        canvasState.mergingCardId = selectedId
                        // Move card toward left edge (main branch position)
                        instance.x = -600
                        instance.y = 0
                    }

                    // Phase 2: Show success toast slightly after animation starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showMergeSuccess = true
                        }
                    }

                    // Phase 3: Remove card after swallow animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        ServerManager.shared.releasePort(for: selectedId)
                        canvasState.removeInstance(selectedId)
                        canvasState.mergingCardId = nil
                    }

                    // Hide toast after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMergeSuccess = false
                        }
                    }

                    isMerging = false
                }
            } catch {
                await MainActor.run {
                    instance.status = .error
                    instance.addMessage(role: .assistant, content: "Merge failed: \(error.localizedDescription)")
                    isMerging = false
                    canvasState.mergingCardId = nil
                }
            }
        }
    }

    private var mergeSuccessToast: some View {
        VStack {
            HStack(spacing: 14) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 36, height: 36)

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Merged successfully")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(mergeMessage)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 20))
                    .foregroundColor(.green.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.1, green: 0.15, blue: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.green.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .frame(maxWidth: 400)
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Input Box

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var inputPlaceholder: String {
        if canvasState.activeCardId != nil {
            return "Message this agent..."
        }
        return "What would you like to build?"
    }

    private var inputBoxView: some View {
        HStack(spacing: 12) {
            // Input field
            TextField(inputPlaceholder, text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .focused($isInputFocused)
                .onSubmit {
                    handleSubmit()
                }

            // Submit button
            Button(action: handleSubmit) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: inputText.isEmpty
                                    ? [Color.white.opacity(0.1), Color.white.opacity(0.08)]
                                    : [Color.white.opacity(0.95), Color.white.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(inputText.isEmpty
                            ? .white.opacity(0.3)
                            : Color(red: 0.1, green: 0.1, blue: 0.12)
                        )
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(inputText.isEmpty)
            .animation(.easeOut(duration: 0.15), value: inputText.isEmpty)
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)

                // Subtle inner glow
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        )
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 8)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .frame(maxWidth: 560)
        .padding(.horizontal, 40)
    }

    private func handleSubmit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let activeId = canvasState.activeCardId,
           let activeInstance = canvasState.instances.first(where: { $0.id == activeId }) {
            // Send message to active agent
            sendMessage(to: activeInstance, text: text)
        } else {
            // Create a new agent
            createNewCoordinator(task: text)
        }
        inputText = ""
    }

    private func sendMessage(to instance: ClaudeInstance, text: String) {
        // Generate smart title for the card (only on first message)
        instance.updateTaskIfNeeded(from: text)

        // Check for duplicate request asynchronously
        Task {
            // Check if this is a duplicate of a previous request
            if !instance.completedRequests.isEmpty {
                let isDuplicate = await ClaudeAPIService.shared.isDuplicateRequest(
                    newRequest: text,
                    previousRequests: instance.completedRequests
                )

                if isDuplicate {
                    // Generate a response explaining the change was already made
                    if let response = await ClaudeAPIService.shared.generateDuplicateResponse(request: text) {
                        await MainActor.run {
                            instance.addMessage(role: .assistant, content: response)
                        }
                    } else {
                        await MainActor.run {
                            instance.addMessage(role: .assistant, content: "This change was already made! Check the preview to see the result.")
                        }
                    }
                    return
                }
            }

            // Not a duplicate - proceed with sending
            await MainActor.run {
                // Add user message
                instance.addMessage(role: .user, content: text)

                // Track this request for duplicate detection
                instance.completedRequests.append(text)

                // If this is a worker, route through coordinator
                if instance.agentType == .worker, let parentId = instance.parentId {
                    // Worker messages go through coordinator
                    if let coordinator = canvasState.instance(for: parentId) {
                        coordinator.addMessage(role: .user, content: "[\(instance.name)] \(text)")
                    }
                }

                // Check if there's a running terminal process (managed by TerminalManager)
                if TerminalManager.shared.isRunning(for: instance.id) {
                    // Send input to existing terminal process with Enter key
                    TerminalManager.shared.sendInput(to: instance.id, text: text, includeReturn: true)
                    instance.status = .running
                } else if ClaudeCodeRunner.shared.isRunning(for: instance.id) {
                    // Fallback: check ClaudeCodeRunner
                    ClaudeCodeRunner.shared.sendInput(to: instance.id, input: text)
                } else {
                    // No process running - start via TerminalManager
                    instance.status = .running
                    TerminalManager.shared.startProcess(for: instance)
                }
            }
        }
    }

    private func createNewCoordinator(task: String) {
        // Reset worker names for this new coordinator
        coordinatorService.resetWorkerNames()

        // Start the coordinator workflow
        Task {
            await coordinatorService.startCoordinator(
                task: task,
                workingDirectory: currentProject?.path
            )
        }
    }

    private func updateWindowBackground(isCardExpanded: Bool) {
        guard let window = NSApplication.shared.windows.first else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().backgroundColor = isCardExpanded
                ? NSColor(hex: "#1E1F23")
                : NSColor(hex: "#151618")
        }
    }

    // MARK: - Server Management

    private func startServerIfNeeded() {
        guard !hasStartedServer, let project = currentProject else { return }
        hasStartedServer = true

        Task {
            // Trust the project directory for Claude operations
            await ClaudeCodeRunner.shared.trustDirectory(project.path)

            // Start the main server
            await ServerManager.shared.startMainServer(in: project.path)
        }
    }

    private func stopServer() {
        ServerManager.shared.stopAllServers()
    }

    // MARK: - Persistence

    private func loadPersistedStateIfNeeded() {
        guard !hasLoadedState, let project = currentProject else { return }
        hasLoadedState = true

        // Load saved canvas state
        if let persisted = PersistenceService.shared.loadCanvasState(for: project.path) {
            PersistenceService.shared.restoreInstances(from: persisted, to: canvasState)
            print("Loaded \(persisted.instances.count) agents from saved state")
        }

        // Start auto-save (every 30 seconds)
        PersistenceService.shared.startAutoSave(canvasState: canvasState, projectPath: project.path)
    }

    private func saveCanvasState() {
        guard let project = currentProject else { return }
        PersistenceService.shared.saveCanvasState(canvasState, projectPath: project.path)
    }
}

// MARK: - Toolbar Button Component

struct ToolbarButton: View {
    let icon: String
    let label: String
    var color: Color = .white
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovered ? color : color.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? color.opacity(0.15) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}


#Preview {
    ContentView()
        .environment(CanvasState())
        .environment(CanvasCoordinator())
        .environment(CoordinatorService())
}
