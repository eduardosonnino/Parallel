import Foundation
import Combine

actor BuildRunner {
    private var projectPath: URL?
    private var currentProcess: Process?

    func setProjectPath(_ path: URL) {
        self.projectPath = path
    }

    func runBuild(command: String) async throws -> String {
        guard let projectPath = projectPath else {
            throw BuildError.noProjectPath
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = projectPath
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        currentProcess = process

        try process.run()
        process.waitUntilExit()

        currentProcess = nil

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        let fullOutput = output + (errorOutput.isEmpty ? "" : "\n\(errorOutput)")

        if process.terminationStatus != 0 {
            throw BuildError.buildFailed(fullOutput)
        }

        return fullOutput
    }

    func runTest(command: String) async throws -> TestResult {
        guard let projectPath = projectPath else {
            throw BuildError.noProjectPath
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = projectPath
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.environment = ProcessInfo.processInfo.environment

        let startTime = Date()
        try process.run()
        process.waitUntilExit()
        let endTime = Date()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return TestResult(
            success: process.terminationStatus == 0,
            output: output + errorOutput,
            duration: endTime.timeIntervalSince(startTime),
            passedTests: parseTestCount(from: output, pattern: #"(\d+) passed"#),
            failedTests: parseTestCount(from: output, pattern: #"(\d+) failed"#),
            skippedTests: parseTestCount(from: output, pattern: #"(\d+) skipped"#)
        )
    }

    private func parseTestCount(from output: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else {
            return 0
        }
        return Int(output[range]) ?? 0
    }

    func cancelBuild() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    func runScript(_ script: String) async throws -> String {
        guard let projectPath = projectPath else {
            throw BuildError.noProjectPath
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.currentDirectoryURL = projectPath
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }

    func detectBuildSystem() async -> BuildSystem? {
        guard let projectPath = projectPath else { return nil }

        let fileManager = FileManager.default
        let path = projectPath.path

        if fileManager.fileExists(atPath: "\(path)/package.json") {
            return .npm
        } else if fileManager.fileExists(atPath: "\(path)/Cargo.toml") {
            return .cargo
        } else if fileManager.fileExists(atPath: "\(path)/Package.swift") {
            return .swift
        } else if fileManager.fileExists(atPath: "\(path)/Makefile") {
            return .make
        } else if fileManager.fileExists(atPath: "\(path)/build.gradle") ||
                  fileManager.fileExists(atPath: "\(path)/build.gradle.kts") {
            return .gradle
        } else if fileManager.fileExists(atPath: "\(path)/pom.xml") {
            return .maven
        } else if fileManager.fileExists(atPath: "\(path)/CMakeLists.txt") {
            return .cmake
        }

        return nil
    }
}

enum BuildError: LocalizedError {
    case noProjectPath
    case buildFailed(String)
    case testFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noProjectPath:
            return "No project path set"
        case .buildFailed(let output):
            return "Build failed:\n\(output)"
        case .testFailed(let output):
            return "Tests failed:\n\(output)"
        case .cancelled:
            return "Build was cancelled"
        }
    }
}

enum BuildSystem: String {
    case npm = "npm"
    case cargo = "cargo"
    case swift = "swift"
    case make = "make"
    case gradle = "gradle"
    case maven = "maven"
    case cmake = "cmake"

    var buildCommand: String {
        switch self {
        case .npm: return "npm run build"
        case .cargo: return "cargo build --release"
        case .swift: return "swift build -c release"
        case .make: return "make"
        case .gradle: return "./gradlew build"
        case .maven: return "mvn package"
        case .cmake: return "cmake --build build"
        }
    }

    var testCommand: String {
        switch self {
        case .npm: return "npm test"
        case .cargo: return "cargo test"
        case .swift: return "swift test"
        case .make: return "make test"
        case .gradle: return "./gradlew test"
        case .maven: return "mvn test"
        case .cmake: return "ctest --test-dir build"
        }
    }
}

struct TestResult {
    let success: Bool
    let output: String
    let duration: TimeInterval
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int

    var totalTests: Int {
        passedTests + failedTests + skippedTests
    }

    var summary: String {
        if success {
            return "\(passedTests) passed, \(skippedTests) skipped"
        } else {
            return "\(failedTests) failed, \(passedTests) passed"
        }
    }
}
