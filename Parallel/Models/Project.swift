import Foundation

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: URL
    var buildCommand: String
    var testCommand: String
    var mainBranch: String
    var createdAt: Date
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        buildCommand: String = "",
        testCommand: String = "npm test",
        mainBranch: String = "main",
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.buildCommand = buildCommand
        self.testCommand = testCommand
        self.mainBranch = mainBranch
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}

struct RecentProject: Identifiable, Codable {
    let id: UUID
    let name: String
    let path: URL
    let lastOpenedAt: Date

    init(from project: Project) {
        self.id = project.id
        self.name = project.name
        self.path = project.path
        self.lastOpenedAt = project.lastOpenedAt
    }
}
