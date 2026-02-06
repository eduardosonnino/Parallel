//
//  AppPreviewPiP.swift
//  Parallel
//
//  Picture-in-Picture draggable app preview
//

import SwiftUI
import AppKit
import WebKit

// MARK: - Mini Preview PiP (Bottom Right Corner)

struct MiniPreviewPiP: View {
    let instance: ClaudeInstance
    let onTap: () -> Void

    @State private var isHovering: Bool = false
    @State private var previewURL: URL?
    @State private var position: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var isServerReady: Bool = false

    private let size = CGSize(width: 240, height: 160)

    // Get the assigned port for this instance
    private var instancePort: Int {
        ServerManager.shared.port(for: instance.id)
    }

    var body: some View {
        pipContent
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(borderOverlay)
            .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
            .scaleEffect(isHovering ? 1.03 : 1.0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .onTapGesture(perform: onTap)
            .gesture(dragGesture)
            .offset(x: position.x, y: position.y)
            .onAppear { findServer() }
    }

    // MARK: - Subviews

    private var pipContent: some View {
        ZStack {
            // Background
            Color(red: 0.08, green: 0.08, blue: 0.1)

            // Web preview (scaled down)
            if let url = previewURL {
                WebPreviewView(url: url)
                    .allowsHitTesting(false)
            } else {
                loadingOrNotRunning
            }

            // Header overlay at top
            VStack {
                headerOverlay
                Spacer()
            }

            // Expand hint on hover
            if isHovering {
                expandHint
            }
        }
    }

    private var headerOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))

            Text("PREVIEW")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.5)
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Circle()
                .fill(previewURL != nil ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var loadingOrNotRunning: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Looking for server...")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var expandHint: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                    Text("Click to expand")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(8)
            }
        }
        .transition(.opacity)
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isHovering ? Color.white.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1)
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                position = CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                )
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    // MARK: - Actions

    private func findServer() {
        Task {
            // Check only the instance's assigned port
            let port = instancePort
            if await isServerRunning(on: port) {
                await MainActor.run {
                    previewURL = URL(string: "http://localhost:\(port)")
                    isServerReady = true
                }
            } else {
                // Retry after delay if not found
                try? await Task.sleep(for: .seconds(2))
                findServer()
            }
        }
    }

    private func isServerRunning(on port: Int) async -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
        } catch {}
        return false
    }
}

// MARK: - Expanded Preview View (Fullscreen)

struct ExpandedPreviewView: View {
    let instance: ClaudeInstance
    let screenSize: CGSize
    let onClose: () -> Void

    @State private var previewURL: URL?
    @State private var isLoading: Bool = true
    @State private var eventMonitor: Any?

    // Get the assigned port for this instance
    private var instancePort: Int {
        ServerManager.shared.port(for: instance.id)
    }

    var body: some View {
        ZStack {
            dimmedBackground
            previewWindow
        }
        .onAppear {
            findPreviewServer()
            setupKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc key
                onClose()
                return nil
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Subviews

    private var dimmedBackground: some View {
        Color.black.opacity(0.85)
            .ignoresSafeArea()
            .onTapGesture { onClose() }
    }

    private var previewWindow: some View {
        VStack(spacing: 0) {
            previewHeader
            previewBody
        }
        .frame(width: min(screenSize.width - 100, 1200), height: min(screenSize.height - 100, 800))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
    }

    private var previewHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 14))
                Text("App Preview")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)

            Spacer()

            if let url = previewURL {
                Text(url.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Esc hint
            Text("esc")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(.trailing, 8)

            refreshButton
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }

    private var refreshButton: some View {
        Button(action: { refreshPreview() }) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var previewBody: some View {
        ZStack {
            if let url = previewURL {
                WebPreviewView(url: url)
            } else if isLoading {
                loadingState
            } else {
                noServerState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.05, green: 0.05, blue: 0.07))
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Looking for dev server...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private var noServerState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.yellow.opacity(0.7))

            Text("No preview server found")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Text("Start a dev server on port 3000, 5173, 8080, or 4200")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            startServerButton
        }
    }

    private var startServerButton: some View {
        Button(action: { startDevServer() }) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text("Start Dev Server")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func findPreviewServer() {
        Task {
            // Check only the instance's assigned port
            let port = instancePort
            if await isServerRunning(on: port) {
                await MainActor.run {
                    previewURL = URL(string: "http://localhost:\(port)")
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }

    private func isServerRunning(on port: Int) async -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
        } catch {}
        return false
    }

    private func refreshPreview() {
        isLoading = true
        previewURL = nil
        findPreviewServer()
    }

    private func startDevServer() {
        guard let workDir = instance.workingDirectory else { return }

        // Start server via ServerManager on the instance's port
        Task {
            await ServerManager.shared.startTaskServer(for: instance.id, in: workDir)

            // Wait a bit then check for server
            try? await Task.sleep(for: .seconds(3))
            findPreviewServer()
        }
    }
}

// MARK: - Web Preview View (Optimized for HMR)

struct WebPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable fast JavaScript execution
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Use separate process for better performance
        config.processPool = WKProcessPool()

        let webView = WKWebView(frame: .zero, configuration: config)

        // Allow inspecting for debugging
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        // Load with cache policy that works well with HMR
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        webView.load(request)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Only reload if URL actually changed (not just the same URL)
        if webView.url?.host != url.host || webView.url?.port != url.port {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            webView.load(request)
        }
    }
}

// MARK: - Legacy AppPreviewPiP (for compatibility)

struct AppPreviewPiP: View {
    let instance: ClaudeInstance

    var body: some View {
        MiniPreviewPiP(instance: instance, onTap: {})
    }
}

// MARK: - Compare Preview View (Side by Side)

struct ComparePreviewView: View {
    let instanceId: UUID
    let screenSize: CGSize
    let onClose: () -> Void

    @Environment(CanvasState.self) private var canvasState

    @State private var eventMonitor: Any?
    @State private var mainURL: URL?
    @State private var taskURL: URL?
    @State private var isLoadingMain: Bool = true
    @State private var isLoadingTask: Bool = true
    @State private var promptText: String = ""
    @FocusState private var isPromptFocused: Bool

    private let mainPort = ServerManager.shared.mainServerPort

    private var taskPort: Int {
        ServerManager.shared.port(for: instanceId)
    }

    private var taskInstance: ClaudeInstance? {
        canvasState.instance(for: instanceId)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                compareHeader

                // Side by side previews
                HStack(spacing: 16) {
                    // Main branch preview (left)
                    previewPane(
                        title: "main",
                        subtitle: "source of truth",
                        port: mainPort,
                        url: mainURL,
                        isLoading: isLoadingMain,
                        color: .green
                    )

                    // Task preview (right)
                    previewPane(
                        title: "task",
                        subtitle: "your changes",
                        port: taskPort,
                        url: taskURL,
                        isLoading: isLoadingTask,
                        color: .blue
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Prompt input for the task agent
                promptInputView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(width: screenSize.width - 80, height: screenSize.height - 80)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        }
        .onAppear {
            setupKeyboardMonitor()
            findServers()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    @State private var isMerging: Bool = false
    @State private var mergeCompleted: Bool = false
    var onMerge: (() -> Void)? = nil

    private var compareHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "square.split.2x1")
                    .font(.system(size: 14))
                Text("Compare Previews")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)

            Spacer()

            // Merge button
            Button(action: performMerge) {
                HStack(spacing: 6) {
                    if isMerging {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else if mergeCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                    } else {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 11))
                    }
                    Text(mergeCompleted ? "Merged" : "Merge to Main")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(mergeCompleted ? Color.green : Color.green.opacity(0.8))
                )
            }
            .buttonStyle(.plain)
            .disabled(isMerging || mergeCompleted)

            // Esc hint
            Text("esc")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func performMerge() {
        guard let instance = taskInstance,
              let workDir = instance.workingDirectory else { return }

        isMerging = true

        Task {
            do {
                try await GitService.shared.mergeBranch("", into: "main", workingDirectory: workDir)
                await MainActor.run {
                    isMerging = false
                    mergeCompleted = true
                    instance.status = .merged
                    onMerge?()

                    // Auto-close after success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onClose()
                    }
                }
            } catch {
                await MainActor.run {
                    isMerging = false
                    instance.addMessage(role: .assistant, content: "Merge failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func previewPane(
        title: String,
        subtitle: String,
        port: Int,
        url: URL?,
        isLoading: Bool,
        color: Color
    ) -> some View {
        VStack(spacing: 0) {
            // Pane header
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text("· \(subtitle)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                Text(":\(port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))

            // Preview content
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)

                if let url = url {
                    WebPreviewView(url: url)
                } else if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow.opacity(0.6))
                        Text("Server not running")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Prompt Input

    private var promptInputView: some View {
        HStack(spacing: 12) {
            // Agent indicator
            if let instance = taskInstance {
                HStack(spacing: 6) {
                    Circle()
                        .fill(instance.status.color)
                        .frame(width: 6, height: 6)
                    Text(instance.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }

            // Text input
            TextField("Send a prompt to this agent...", text: $promptText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($isPromptFocused)
                .onSubmit { sendPrompt() }

            // Send button
            Button(action: sendPrompt) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(promptText.isEmpty ? .white.opacity(0.3) : .blue)
            }
            .buttonStyle(.plain)
            .disabled(promptText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private func sendPrompt() {
        let text = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let instance = taskInstance else { return }

        // Add user message to the instance
        instance.addMessage(role: .user, content: text)

        // If this is a worker with a parent coordinator, also notify the coordinator
        if instance.agentType == .worker, let parentId = instance.parentId,
           let coordinator = canvasState.instance(for: parentId) {
            coordinator.addMessage(role: .user, content: "[\(instance.name)] \(text)")
        }

        // Check if there's a running terminal process (managed by TerminalManager)
        if TerminalManager.shared.isRunning(for: instance.id) {
            // Send input to existing terminal process
            // Use carriage return (\r) to submit the command
            TerminalManager.shared.sendInput(to: instance.id, text: text + "\r")
            instance.status = .running
        } else if ClaudeCodeRunner.shared.isRunning(for: instance.id) {
            // Fallback: check ClaudeCodeRunner
            ClaudeCodeRunner.shared.sendInput(to: instance.id, input: text)
        } else {
            // No process running - start via TerminalManager
            instance.status = .running
            TerminalManager.shared.startProcess(for: instance)
        }

        // Clear the input
        promptText = ""
    }

    private func findServers() {
        Task {
            // Check main server
            if await isServerRunning(on: mainPort) {
                await MainActor.run {
                    mainURL = URL(string: "http://localhost:\(mainPort)")
                    isLoadingMain = false
                }
            } else {
                await MainActor.run { isLoadingMain = false }
            }

            // Check task server
            if await isServerRunning(on: taskPort) {
                await MainActor.run {
                    taskURL = URL(string: "http://localhost:\(taskPort)")
                    isLoadingTask = false
                }
            } else {
                await MainActor.run { isLoadingTask = false }
            }
        }
    }

    private func isServerRunning(on port: Int) async -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
        } catch {}
        return false
    }

    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc key
                onClose()
                return nil
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Two Agent Compare View (Side by Side)

struct TwoAgentCompareView: View {
    let firstInstanceId: UUID
    let secondInstanceId: UUID
    let screenSize: CGSize
    let onClose: () -> Void

    @Environment(CanvasState.self) private var canvasState

    @State private var eventMonitor: Any?
    @State private var firstURL: URL?
    @State private var secondURL: URL?
    @State private var isLoadingFirst: Bool = true
    @State private var isLoadingSecond: Bool = true

    private var firstPort: Int {
        ServerManager.shared.port(for: firstInstanceId)
    }

    private var secondPort: Int {
        ServerManager.shared.port(for: secondInstanceId)
    }

    private var firstInstance: ClaudeInstance? {
        canvasState.instance(for: firstInstanceId)
    }

    private var secondInstance: ClaudeInstance? {
        canvasState.instance(for: secondInstanceId)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                compareHeader

                // Side by side previews
                HStack(spacing: 16) {
                    // First agent preview (left)
                    agentPreviewPane(
                        instance: firstInstance,
                        port: firstPort,
                        url: firstURL,
                        isLoading: isLoadingFirst,
                        color: .blue
                    )

                    // Second agent preview (right)
                    agentPreviewPane(
                        instance: secondInstance,
                        port: secondPort,
                        url: secondURL,
                        isLoading: isLoadingSecond,
                        color: .purple
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .frame(width: screenSize.width - 80, height: screenSize.height - 80)
            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        }
        .onAppear {
            setupKeyboardMonitor()
            findServers()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    private var compareHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "square.split.2x1")
                    .font(.system(size: 14))
                Text("Compare Agents")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)

            Spacer()

            // Agent names
            if let first = firstInstance, let second = secondInstance {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text(first.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text("vs")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    HStack(spacing: 4) {
                        Circle().fill(Color.purple).frame(width: 6, height: 6)
                        Text(second.name)
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Esc hint
            Text("esc")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func agentPreviewPane(
        instance: ClaudeInstance?,
        port: Int,
        url: URL?,
        isLoading: Bool,
        color: Color
    ) -> some View {
        VStack(spacing: 0) {
            // Pane header
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(instance?.name ?? "Agent")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                if let task = instance?.task {
                    Text("· \(task.prefix(30))\(task.count > 30 ? "..." : "")")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Text(":\(port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))

            // Preview content
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.07)

                if let url = url {
                    WebPreviewView(url: url)
                } else if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow.opacity(0.6))
                        Text("Server not running")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func findServers() {
        Task {
            // Check first agent server
            if await isServerRunning(on: firstPort) {
                await MainActor.run {
                    firstURL = URL(string: "http://localhost:\(firstPort)")
                    isLoadingFirst = false
                }
            } else {
                await MainActor.run { isLoadingFirst = false }
            }

            // Check second agent server
            if await isServerRunning(on: secondPort) {
                await MainActor.run {
                    secondURL = URL(string: "http://localhost:\(secondPort)")
                    isLoadingSecond = false
                }
            } else {
                await MainActor.run { isLoadingSecond = false }
            }
        }
    }

    private func isServerRunning(on port: Int) async -> Bool {
        guard let url = URL(string: "http://localhost:\(port)") else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode < 500
            }
        } catch {}
        return false
    }

    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc key
                onClose()
                return nil
            }
            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
