//
//  MainBranchCard.swift
//  Parallel
//
//  Floating "Main Branch" bubble - drop target for merging
//  Shows live preview and accepts card drops
//

import SwiftUI
import WebKit

// MARK: - Main Branch Bubble

struct MainBranchCard: View {
    let screenSize: CGSize
    let workingDirectory: String?

    @Environment(CanvasState.self) private var canvasState

    @State private var isHovering: Bool = false
    @State private var isDragOver: Bool = false
    @State private var isExpanded: Bool = false
    @State private var isFullScreen: Bool = false
    @State private var showMergeSuccess: Bool = false
    @State private var mergeMessage: String = ""
    @State private var position: CGPoint = .zero
    @State private var isAbsorbing: Bool = false  // Pulse effect when merging

    // Bubble sizing
    private let collapsedSize = CGSize(width: 140, height: 48)
    private let expandedSize = CGSize(width: 320, height: 240)

    private var currentSize: CGSize {
        if isFullScreen { return screenSize }
        return isExpanded || isDragOver ? expandedSize : collapsedSize
    }

    var body: some View {
        ZStack {
            // Full-screen overlay
            if isFullScreen {
                fullScreenView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // The floating bubble
                ZStack {
                    // Absorbing glow effect when merging
                    if isAbsorbing {
                        RoundedRectangle(cornerRadius: isExpanded ? 16 : 24, style: .continuous)
                            .fill(Color.green)
                            .frame(width: currentSize.width + 20, height: currentSize.height + 20)
                            .blur(radius: 20)
                            .opacity(0.6)
                            .scaleEffect(isAbsorbing ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.4).repeatCount(2, autoreverses: true), value: isAbsorbing)
                    }

                    bubbleContent
                        .frame(width: currentSize.width, height: currentSize.height)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 16 : 24, style: .continuous))
                        .overlay(bubbleBorder)
                        .overlay(
                            // Absorbing border pulse
                            RoundedRectangle(cornerRadius: isExpanded ? 16 : 24, style: .continuous)
                                .stroke(Color.green, lineWidth: isAbsorbing ? 4 : 0)
                                .scaleEffect(isAbsorbing ? 1.1 : 1.0)
                                .opacity(isAbsorbing ? 1.0 : 0)
                                .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: isAbsorbing)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .shadow(color: (isDragOver || isAbsorbing) ? Color.green.opacity(0.5) : .clear, radius: isAbsorbing ? 30 : 20, x: 0, y: 0)
                        .scaleEffect(isAbsorbing ? 1.08 : (isDragOver ? 1.05 : (isHovering ? 1.02 : 1.0)))
                }
                .position(bubblePosition)
                .gesture(dragGesture)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }
                .onDrop(of: [.text], isTargeted: $isDragOver) { providers in
                    handleDrop(providers: providers)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentSize)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragOver)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAbsorbing)
            }

            // Merge success toast
            if showMergeSuccess {
                mergeSuccessToast
            }
        }
        .onAppear {
            // Position in bottom-left corner
            position = CGPoint(
                x: 100,
                y: screenSize.height - 80
            )
        }
        .onChange(of: canvasState.mergingCardId) { _, newValue in
            // Trigger absorbing animation when a card starts merging
            if newValue != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAbsorbing = true
                }
                // Turn off after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isAbsorbing = false
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isFullScreen)
    }

    private var bubblePosition: CGPoint {
        CGPoint(
            x: position.x + (isExpanded ? (expandedSize.width - collapsedSize.width) / 2 : 0),
            y: position.y - (isExpanded ? (expandedSize.height - collapsedSize.height) / 2 : 0)
        )
    }

    // MARK: - Bubble Content

    private var bubbleContent: some View {
        VStack(spacing: 0) {
            if isExpanded || isDragOver {
                expandedContent
            } else {
                collapsedContent
            }
        }
    }

    private var collapsedContent: some View {
        HStack(spacing: 10) {
            // Branch icon
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)

            Text("main")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            // Status dot
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            // Expand chevron
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 16)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)

                Text("main")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text("· source of truth")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Full-screen button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isFullScreen = true
                        isExpanded = false
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Preview or drop zone
            ZStack {
                if isDragOver {
                    // Drop zone indicator
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)

                        Text("Drop to merge into main")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.green.opacity(0.1))
                } else {
                    // Live preview
                    BubblePreviewView(workingDirectory: workingDirectory)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Full Screen View

    @State private var fullScreenEventMonitor: Any?

    private var fullScreenView: some View {
        ZStack {
            // Dimmed background - click to close
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    closeFullScreen()
                }

            // Centered preview window
            VStack(spacing: 0) {
                // Header bar
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)

                    Text("main")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("· source of truth")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)

                    Text("localhost:\(ServerManager.shared.mainServerPort)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))

                    // Esc hint
                    Text("esc")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Close button
                    Button(action: closeFullScreen) {
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
                .background(Color(red: 0.1, green: 0.1, blue: 0.12))

                // Preview content - interactive in fullscreen
                BubblePreviewView(workingDirectory: workingDirectory, interactive: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.07))
            }
            .frame(width: min(screenSize.width - 100, 1200), height: min(screenSize.height - 100, 800))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
        }
        .onAppear {
            setupFullScreenKeyboardMonitor()
        }
        .onDisappear {
            removeFullScreenKeyboardMonitor()
        }
    }

    private func closeFullScreen() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isFullScreen = false
        }
    }

    private func setupFullScreenKeyboardMonitor() {
        fullScreenEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc key
                closeFullScreen()
                return nil
            }
            return event
        }
    }

    private func removeFullScreenKeyboardMonitor() {
        if let monitor = fullScreenEventMonitor {
            NSEvent.removeMonitor(monitor)
            fullScreenEventMonitor = nil
        }
    }

    // MARK: - Styling

    private var bubbleBackground: some View {
        Color(red: 0.1, green: 0.1, blue: 0.12)
    }

    private var bubbleBorder: some View {
        RoundedRectangle(cornerRadius: isExpanded ? 16 : 24, style: .continuous)
            .stroke(
                isDragOver ? Color.green : Color.white.opacity(0.15),
                lineWidth: isDragOver ? 2 : 1
            )
    }

    // MARK: - Drag Gesture (to reposition bubble)

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                position = CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                )
            }
            .onEnded { _ in
                // Snap to edges if close
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    snapToEdge()
                }
            }
    }

    private func snapToEdge() {
        let margin: CGFloat = 20
        let halfWidth = currentSize.width / 2
        let halfHeight = currentSize.height / 2

        // Keep within bounds
        position.x = max(halfWidth + margin, min(screenSize.width - halfWidth - margin, position.x))
        position.y = max(halfHeight + margin, min(screenSize.height - halfHeight - margin, position.y))
    }

    // MARK: - Merge Success Toast

    private var mergeSuccessToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Merged successfully")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(mergeMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.1, green: 0.15, blue: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .position(x: screenSize.width / 2, y: 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Use the currently selected/dragged instance
        if let selectedId = canvasState.selectedIds.first,
           let instance = canvasState.instance(for: selectedId) {
            performMerge(instance: instance)
            return true
        }
        return false
    }

    private func performMerge(instance: ClaudeInstance) {
        guard let workDir = workingDirectory ?? instance.workingDirectory else { return }

        let branchName = instance.branchName.isEmpty ? "feature-\(instance.name.lowercased())" : instance.branchName

        Task {
            do {
                try await GitService.shared.mergeBranch(
                    branchName,
                    into: "main",
                    workingDirectory: workDir
                )

                await MainActor.run {
                    mergeMessage = "\(branchName) → main"
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showMergeSuccess = true
                        isExpanded = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMergeSuccess = false
                        }
                    }

                    instance.status = .completed
                }
            } catch {
                print("Merge failed: \(error)")
            }
        }
    }
}

// MARK: - Bubble Preview View (Main Branch Only - Port 3000)

struct BubblePreviewView: View {
    let workingDirectory: String?
    var interactive: Bool = false

    @State private var previewURL: URL?
    @State private var isLoading: Bool = true
    @State private var refreshId: UUID = UUID()

    // Main branch always uses port 3000
    private let mainPort = ServerManager.shared.mainServerPort

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.07)

            if let url = previewURL {
                RetryingWebPreviewView(url: url, refreshId: refreshId)
                    .allowsHitTesting(interactive)
            } else if isLoading {
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                    Text("Loading preview...")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No server on :\(mainPort)")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.3))

                    Button("Retry") {
                        isLoading = true
                        loadPreview()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            loadPreview()
        }
    }

    private func loadPreview() {
        // Just load the URL directly - let WKWebView handle retries
        // ServerManager already validated the server is healthy
        previewURL = URL(string: "http://localhost:\(mainPort)")
        isLoading = false
    }
}

// MARK: - Retrying Web Preview (handles WKWebView timeouts)

struct RetryingWebPreviewView: NSViewRepresentable {
    let url: URL
    let refreshId: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.processPool = WKProcessPool()

        // Increase timeouts
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        // Custom request with longer timeout
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        webView.load(request)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload if refresh requested or URL changed
        if webView.url?.absoluteString != url.absoluteString {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            webView.load(request)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var retryCount = 0
        let maxRetries = 3

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }

        private func handleError(_ error: Error) {
            let nsError = error as NSError
            print("WebView error: \(nsError.code) - \(error.localizedDescription)")

            // Retry on timeout (-1001) or connection errors
            if retryCount < maxRetries && (nsError.code == -1001 || nsError.code == -1004 || nsError.code == -1009) {
                retryCount += 1
                print("Retrying WebView load (attempt \(retryCount)/\(maxRetries))...")

                DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryCount)) {
                    if let webView = self.webView, let url = webView.url ?? URL(string: "http://localhost:3000") {
                        var request = URLRequest(url: url)
                        request.cachePolicy = .reloadIgnoringLocalCacheData
                        request.timeoutInterval = 30
                        webView.load(request)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            retryCount = 0  // Reset on success
        }
    }
}

// MARK: - Git Service

@MainActor
final class GitService {
    static let shared = GitService()

    private init() {}

    /// Merge changes from isolated copy back to main project
    /// Since we use directory copies (not git branches), this syncs files back
    func mergeBranch(_ branch: String, into target: String, workingDirectory: String) async throws -> Bool {
        // workingDirectory is the isolated copy (.parallel/agent-XXX)
        // We need to find the main project directory (parent of .parallel)

        guard let mainProject = findMainProject(from: workingDirectory) else {
            throw GitError.commandFailed("Could not find main project directory")
        }

        print("Merging changes from \(workingDirectory) to \(mainProject)")

        // Use rsync to copy changed files back to main
        // Exclude .parallel, node_modules, .git, .next to avoid overwriting
        try await syncChanges(from: workingDirectory, to: mainProject)

        return true
    }

    /// Find the main project directory from an isolated copy path
    private func findMainProject(from isolatedPath: String) -> String? {
        // Path is like: /project/.parallel/agent-XXX
        // We want: /project
        let nsPath = isolatedPath as NSString

        // Check if this is inside .parallel
        if nsPath.lastPathComponent.hasPrefix("agent-"),
           nsPath.deletingLastPathComponent.hasSuffix(".parallel") {
            // Go up two levels: agent-XXX -> .parallel -> project
            return (nsPath.deletingLastPathComponent as NSString).deletingLastPathComponent
        }

        return nil
    }

    /// Sync changes from isolated copy back to main project
    private func syncChanges(from source: String, to destination: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/rsync")
            process.arguments = [
                "-av",
                "--exclude=.parallel",
                "--exclude=node_modules",
                "--exclude=.git",
                "--exclude=.next",
                "--exclude=.DS_Store",
                source + "/",
                destination + "/"
            ]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    print("Merge completed: \(output)")
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GitError.commandFailed(output))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func getCurrentBranch(in workingDirectory: String) async -> String? {
        do {
            let output = try await runGitCommand(["branch", "--show-current"], in: workingDirectory)
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    @discardableResult
    private func runGitCommand(_ args: [String], in workingDirectory: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: GitError.commandFailed(output))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum GitError: Error {
    case commandFailed(String)
}
