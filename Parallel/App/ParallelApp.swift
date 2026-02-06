//
//  ParallelApp.swift
//  Parallel
//
//  Main app entry point
//

import SwiftUI
import AppKit

// MARK: - Environment Key for Current Project

private struct CurrentProjectKey: EnvironmentKey {
    static let defaultValue: ProjectInfo? = nil
}

extension EnvironmentValues {
    var currentProject: ProjectInfo? {
        get { self[CurrentProjectKey.self] }
        set { self[CurrentProjectKey.self] = newValue }
    }
}

@main
struct ParallelApp: App {
    @State private var canvasState = CanvasState()
    @State private var coordinator = CanvasCoordinator()
    @State private var coordinatorService = CoordinatorService()
    @State private var selectedProject: ProjectInfo?

    var body: some Scene {
        WindowGroup {
            Group {
                if let project = selectedProject {
                    ContentView()
                        .environment(canvasState)
                        .environment(coordinator)
                        .environment(coordinatorService)
                        .environment(\.currentProject, project)
                        .onAppear {
                            coordinator.configure(canvasState: canvasState)
                            coordinatorService.canvasState = canvasState
                            configureWindow()
                        }
                } else {
                    WelcomeView(selectedProject: $selectedProject)
                        .onAppear {
                            configureWindow()
                        }
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: WindowConstraints.defaultWidth,
            height: WindowConstraints.defaultHeight
        )
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Instance") {
                    addNewInstance()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Select All") {
                    canvasState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("Delete Selected") {
                    coordinator.deleteSelected()
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }

            CommandMenu("Canvas") {
                Picker("View Mode", selection: Binding(
                    get: { canvasState.viewMode },
                    set: { newMode in
                        withAnimation(CanvasAnimations.mainTransition) {
                            canvasState.viewMode = newMode
                        }
                    }
                )) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
        }
    }

    private func addNewInstance() {
        let names = ["Atlas", "Nova", "Cipher", "Pulse", "Echo", "Nexus", "Quantum", "Vector"]
        let randomName = names.randomElement() ?? "Claude"

        coordinator.addInstance(
            name: randomName,
            task: "Working on a new feature...",
            at: CGPoint(
                x: Double.random(in: -200...200),
                y: Double.random(in: -200...200)
            )
        )
    }


    private func configureWindow() {
        // Configure the main window for modern appearance
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Fully transparent titlebar that blends seamlessly with content
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.toolbar = nil

                // Allow content to extend into titlebar area
                window.styleMask.insert(.fullSizeContentView)

                // Window shadow but NOT movable by background (conflicts with card drag)
                window.hasShadow = true
                window.isMovableByWindowBackground = false

                // Clear background - let SwiftUI content provide the color
                window.backgroundColor = .clear
                window.isOpaque = false

                // Disable the focus ring on the window
                window.autorecalculatesKeyViewLoop = false
            }
        }

        // Disable focus ring globally for this app
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }
}

