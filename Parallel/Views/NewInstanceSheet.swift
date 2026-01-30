import SwiftUI

struct NewInstanceSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var instanceName: String = ""
    @State private var taskDescription: String = ""
    @State private var customBranch: String = ""
    @State private var useCustomBranch: Bool = false
    @State private var isolationMode: IsolationMode = .worktree
    @State private var isCreating: Bool = false

    var isValid: Bool {
        !instanceName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !taskDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var generatedBranchName: String {
        let sanitized = instanceName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
        return "claude/\(sanitized)-\(UUID().uuidString.prefix(6).lowercased())"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Instance")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Create a new Claude Code instance")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Instance name
                    FormSection(title: "Instance Name", hint: "A short, descriptive name") {
                        TextField("e.g., Feature Auth, Bug Fix #123", text: $instanceName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Task description
                    FormSection(title: "Task Description", hint: "What should Claude work on?") {
                        TextEditor(text: $taskDescription)
                            .font(.system(size: 12))
                            .frame(minHeight: 80, maxHeight: 150)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    // Isolation mode
                    FormSection(title: "Isolation Mode") {
                        VStack(spacing: 8) {
                            IsolationModeOption(
                                mode: .worktree,
                                isSelected: isolationMode == .worktree,
                                action: { isolationMode = .worktree }
                            )

                            IsolationModeOption(
                                mode: .shared,
                                isSelected: isolationMode == .shared,
                                action: { isolationMode = .shared }
                            )
                        }
                    }

                    // Branch settings
                    FormSection(title: "Branch") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $useCustomBranch) {
                                Text("Use custom branch name")
                                    .font(.system(size: 12))
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            if useCustomBranch {
                                TextField("Branch name", text: $customBranch)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11, design: .monospaced))
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    Text(instanceName.isEmpty ? "claude/instance-name-xxxxxx" : generatedBranchName)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    // Project info
                    if let project = appState.currentProject {
                        FormSection(title: "Project") {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(LinearGradient(
                                            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 28, height: 28)

                                    Text(String(project.name.prefix(1)).uppercased())
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.system(size: 12, weight: .medium))

                                    Text(project.path.path)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }

                                Spacer()
                            }
                            .padding(10)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button {
                    createInstance()
                } label: {
                    HStack(spacing: 6) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .medium))
                        }
                        Text(isCreating ? "Creating..." : "Create Instance")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isCreating)
                .keyboardShortcut(.return)
            }
            .padding(20)
        }
        .frame(width: 460, height: 540)
    }

    private func createInstance() {
        isCreating = true

        let branchName = useCustomBranch ? customBranch : generatedBranchName

        Task {
            await appState.createInstance(
                name: instanceName.trimmingCharacters(in: .whitespaces),
                task: taskDescription.trimmingCharacters(in: .whitespaces),
                branchName: branchName.isEmpty ? nil : branchName,
                isolationMode: isolationMode
            )

            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views

struct FormSection<Content: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                if let hint = hint {
                    Text("- \(hint)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            content()
        }
    }
}

struct IsolationModeOption: View {
    let mode: IsolationMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)

                    Image(systemName: mode == .worktree ? "lock.shield.fill" : "folder.badge.gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)

                    Text(mode == .worktree ?
                         "Main project stays buildable" :
                         "Edits files directly")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : (isHovered ? Color.secondary.opacity(0.05) : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var iconColor: Color {
        mode == .worktree ? .green : .orange
    }
}

#Preview {
    NewInstanceSheet()
        .environmentObject(AppState())
}
