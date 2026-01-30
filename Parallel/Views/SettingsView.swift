import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("claudePath") private var claudePath: String = "/usr/local/bin/claude"
    @AppStorage("defaultCommitStrategy") private var defaultStrategy: CommitStrategy = .separateBranches
    @AppStorage("autoBuildOnReady") private var autoBuildOnReady: Bool = false
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("terminalFontSize") private var terminalFontSize: Double = 12

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            gitSettings
                .tabItem {
                    Label("Git", systemImage: "arrow.triangle.branch")
                }

            appearanceSettings
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
        }
        .frame(width: 500, height: 400)
    }

    private var generalSettings: some View {
        Form {
            Section("Claude Code") {
                HStack {
                    TextField("Path to Claude CLI", text: $claudePath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse...") {
                        selectClaudePath()
                    }
                }

                Text("Path to the Claude Code CLI executable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Build") {
                Toggle("Auto-build when all instances are ready", isOn: $autoBuildOnReady)

                Toggle("Show build notifications", isOn: $showNotifications)
            }

            Section("Behavior") {
                Toggle("Show confirmation before stopping instances", isOn: .constant(true))

                Toggle("Remember window positions", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var gitSettings: some View {
        Form {
            Section("Default Commit Strategy") {
                Picker("Strategy", selection: $defaultStrategy) {
                    ForEach(CommitStrategy.allCases, id: \.self) { strategy in
                        VStack(alignment: .leading) {
                            Text(strategy.displayName)
                            Text(strategy.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(strategy)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Branch Naming") {
                TextField("Branch prefix", text: .constant("claude/"))
                    .textFieldStyle(.roundedBorder)

                Text("All branches created by Parallel will start with this prefix")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Push Settings") {
                Toggle("Auto-push after commit", isOn: .constant(false))

                Toggle("Force push (dangerous)", isOn: .constant(false))
                    .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appearanceSettings: some View {
        Form {
            Section("Terminal") {
                HStack {
                    Text("Font Size")
                    Slider(value: $terminalFontSize, in: 10...20, step: 1)
                    Text("\(Int(terminalFontSize))pt")
                        .frame(width: 40)
                }

                Picker("Theme", selection: .constant("dark")) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("System").tag("system")
                }
            }

            Section("Instance Cards") {
                Picker("Card Size", selection: .constant("medium")) {
                    Text("Compact").tag("compact")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                }

                Toggle("Show task preview", isOn: .constant(true))

                Toggle("Show branch name", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func selectClaudePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the Claude CLI executable"

        if panel.runModal() == .OK, let url = panel.url {
            claudePath = url.path
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
