import SwiftUI

@main
struct ParallelApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Instance") {
                    appState.showNewInstanceSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Open Project...") {
                    appState.openProjectPicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandMenu("Instances") {
                Button("Run All Ready") {
                    Task {
                        await appState.runBuildIfAllReady()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!appState.allInstancesReady)

                Divider()

                Button("Stop All") {
                    appState.stopAllInstances()
                }
                .keyboardShortcut(".", modifiers: .command)
            }

            CommandMenu("Git") {
                Button("Commit All Changes") {
                    Task {
                        await appState.commitAllChanges()
                    }
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Push All") {
                    Task {
                        await appState.pushAllChanges()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Divider()

                Button("Merge All to Main") {
                    Task {
                        await appState.mergeAllToMain()
                    }
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
