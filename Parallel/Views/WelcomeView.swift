//
//  WelcomeView.swift
//  Parallel
//
//  Welcome screen with 50/50 layout for opening projects
//

import SwiftUI
import AppKit

struct WelcomeView: View {
    @Binding var selectedProject: ProjectInfo?
    @State private var recentProjects: [ProjectInfo] = []
    @State private var isHoveringOpen: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Open Project
            leftPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1)

            // Right side - Recent Projects
            rightPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignColors.canvasBackground)
        .onAppear {
            loadRecentProjects()
        }
    }

    // MARK: - Left Panel (Open Project)

    private var leftPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Icon
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.white.opacity(0.6))

                // Title
                VStack(spacing: 8) {
                    Text("Open a Project")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Select a folder to start working with Claude")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Open button
                Button(action: openProjectPicker) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 16, weight: .medium))
                        Text("Choose Folder")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(isHoveringOpen ? 0.15 : 0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringOpen = hovering
                    }
                }

                // Keyboard shortcut hint
                Text("⌘O")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Right Panel (Recent Projects)

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Recent Projects")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if !recentProjects.isEmpty {
                    Button("Clear") {
                        clearRecentProjects()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Projects list
            if recentProjects.isEmpty {
                emptyRecentState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recentProjects) { project in
                            RecentProjectRow(project: project) {
                                selectProject(project)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyRecentState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "clock")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(.white.opacity(0.2))

            Text("No recent projects")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func openProjectPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Open"
        panel.message = "Select a project folder to work with Claude"

        if panel.runModal() == .OK, let url = panel.url {
            let project = ProjectInfo(
                id: UUID(),
                name: url.lastPathComponent,
                path: url.path,
                lastOpened: Date()
            )
            addToRecentProjects(project)
            selectProject(project)
        }
    }

    private func selectProject(_ project: ProjectInfo) {
        selectedProject = project
    }

    private func loadRecentProjects() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "recentProjects"),
           let projects = try? JSONDecoder().decode([ProjectInfo].self, from: data) {
            recentProjects = projects.sorted { $0.lastOpened > $1.lastOpened }
        }
    }

    private func addToRecentProjects(_ project: ProjectInfo) {
        // Remove if already exists
        recentProjects.removeAll { $0.path == project.path }

        // Add to front
        recentProjects.insert(project, at: 0)

        // Keep only last 10
        if recentProjects.count > 10 {
            recentProjects = Array(recentProjects.prefix(10))
        }

        // Save
        saveRecentProjects()
    }

    private func saveRecentProjects() {
        if let data = try? JSONEncoder().encode(recentProjects) {
            UserDefaults.standard.set(data, forKey: "recentProjects")
        }
    }

    private func clearRecentProjects() {
        recentProjects.removeAll()
        UserDefaults.standard.removeObject(forKey: "recentProjects")
    }
}

// MARK: - Recent Project Row

struct RecentProjectRow: View {
    let project: ProjectInfo
    let action: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Folder icon
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 40)

                // Project info
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                // Time ago
                Text(timeAgo(project.lastOpened))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }

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

// MARK: - Project Info Model

struct ProjectInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let path: String
    var lastOpened: Date
}

// MARK: - Preview

#Preview {
    WelcomeView(selectedProject: .constant(nil))
        .frame(width: 900, height: 600)
}
