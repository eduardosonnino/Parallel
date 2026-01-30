import SwiftUI

struct NewInstanceSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var instanceName: String = ""
    @State private var taskDescription: String = ""
    @State private var customBranch: String = ""
    @State private var useCustomBranch: Bool = false
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
                Text("New Claude Instance")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)

            Divider()

            // Form content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Instance name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instance Name")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("e.g., Feature Auth, Bug Fix #123", text: $instanceName)
                            .textFieldStyle(.roundedBorder)

                        Text("A short, descriptive name for this instance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Task description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Description")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextEditor(text: $taskDescription)
                            .font(.body)
                            .frame(minHeight: 100, maxHeight: 200)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )

                        Text("Describe what you want Claude to do. Be specific about the requirements.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Branch settings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Branch")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Toggle("Use custom branch name", isOn: $useCustomBranch)
                            .font(.subheadline)

                        if useCustomBranch {
                            TextField("Branch name", text: $customBranch)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .foregroundColor(.secondary)

                                Text(instanceName.isEmpty ? "claude/instance-name-xxxxxx" : generatedBranchName)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Project info
                    if let project = appState.currentProject {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Project")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.name)
                                        .font(.subheadline)

                                    Text(project.path.path)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(24)
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
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 60)
                    } else {
                        Text("Create")
                            .frame(width: 60)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isCreating)
                .keyboardShortcut(.return)
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 500, height: 550)
    }

    private func createInstance() {
        isCreating = true

        let branchName = useCustomBranch ? customBranch : generatedBranchName

        Task {
            await appState.createInstance(
                name: instanceName.trimmingCharacters(in: .whitespaces),
                task: taskDescription.trimmingCharacters(in: .whitespaces),
                branchName: branchName.isEmpty ? nil : branchName
            )

            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

struct QuickTemplateButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(.caption)
            }
            .frame(width: 80, height: 70)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewInstanceSheet()
        .environmentObject(AppState())
}
