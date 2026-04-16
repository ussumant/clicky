//
//  PawscriptCodexExecutor.swift
//  leanring-buddy
//
//  Runs Codex CLI in a safe Pawscript demo workspace.
//

import Foundation

enum PawscriptCodexExecutorError: LocalizedError {
    case codexNotFound
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Install or log in to Codex first."
        case .executionFailed(let detail):
            return "Codex execution failed: \(detail)"
        }
    }
}

struct PawscriptCodexExecutionResult {
    var output: String
    var workspaceURL: URL
}

final class PawscriptCodexExecutor {
    var defaultWorkspaceURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent("PawscriptDemo", isDirectory: true)
    }

    func run(prompt: String, workspaceURL: URL? = nil) async throws -> PawscriptCodexExecutionResult {
        let resolvedWorkspaceURL = workspaceURL ?? defaultWorkspaceURL
        try FileManager.default.createDirectory(at: resolvedWorkspaceURL, withIntermediateDirectories: true)

        let codexPath = try resolveCodexBinary()
        let output = try await executeCodex(
            codexPath: codexPath,
            prompt: prompt,
            workspaceURL: resolvedWorkspaceURL
        )

        return PawscriptCodexExecutionResult(output: output, workspaceURL: resolvedWorkspaceURL)
    }

    private func resolveCodexBinary() throws -> String {
        let candidates = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(NSHomeDirectory())/.npm-global/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["codex"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw PawscriptCodexExecutorError.codexNotFound
    }

    private func buildEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = "/usr/local/bin:/opt/homebrew/bin:\(NSHomeDirectory())/.npm-global/bin:\(NSHomeDirectory())/.local/bin"
        environment["PATH"] = "\(extraPaths):\(environment["PATH"] ?? "/usr/bin:/bin")"
        return environment
    }

    private func executeCodex(codexPath: String, prompt: String, workspaceURL: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["exec", prompt, "--full-auto"]
        process.currentDirectoryURL = workspaceURL
        process.environment = buildEnvironment()
        process.standardInput = Pipe()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: Self.extractResponse(from: stdout))
                } else {
                    let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Codex exited with code \(process.terminationStatus)"
                        : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: PawscriptCodexExecutorError.executionFailed(detail))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: PawscriptCodexExecutorError.executionFailed(error.localizedDescription))
            }
        }
    }

    private static func extractResponse(from stdout: String) -> String {
        let markerResponse = CodexResponseExtractor.extractResponse(from: stdout)
        if !markerResponse.isEmpty {
            return markerResponse
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CodexResponseExtractor {
    static func extractResponse(from stdout: String) -> String {
        let lines = stdout.components(separatedBy: "\n")
        var foundCodexMarker = false
        var responseLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "codex" {
                foundCodexMarker = true
                continue
            }
            if foundCodexMarker {
                if trimmed == "tokens used" {
                    break
                }
                responseLines.append(line)
            }
        }

        return responseLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
