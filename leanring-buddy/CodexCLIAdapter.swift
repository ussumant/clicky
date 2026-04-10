//
//  CodexCLIAdapter.swift
//  leanring-buddy
//
//  Codex CLI adapter for Clicky. Routes chat requests through the
//  locally-installed `codex` binary (OpenAI Codex CLI) using `exec`
//  mode with --full-auto. Uses the user's existing OpenAI/Codex
//  subscription — no separate API key needed.
//
//  Pattern follows ClaudeCLIAdapter.swift.
//

import Foundation

// MARK: - Errors

enum CodexCLIError: LocalizedError {
    case binaryNotFound
    case notAuthenticated
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Codex CLI not found. Install: npm install -g @openai/codex"
        case .notAuthenticated:
            return "Codex CLI not authenticated. Run 'codex login' in your terminal."
        case .executionFailed(let detail):
            return "Codex CLI error: \(detail)"
        }
    }
}

// MARK: - CodexCLIAdapter

/// Routes chat requests through the locally-installed Codex CLI binary.
@MainActor
final class CodexCLIAdapter {

    var model: String = "gpt-5.4"

    /// Candidate paths for the Codex binary
    private static let binaryCandidates = [
        "/usr/local/bin/codex",
        "/opt/homebrew/bin/codex",
        "\(NSHomeDirectory())/.npm-global/bin/codex",
        "\(NSHomeDirectory())/.local/bin/codex"
    ]

    func isCLIAvailable() -> Bool {
        return (try? resolveBinary()) != nil
    }

    // MARK: - Binary Resolution

    nonisolated private func resolveBinary() throws -> String {
        for path in CodexCLIAdapter.binaryCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["codex"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw CodexCLIError.binaryNotFound
    }

    nonisolated private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/usr/local/bin:/opt/homebrew/bin:\(NSHomeDirectory())/.npm-global/bin:\(NSHomeDirectory())/.local/bin"
        env["PATH"] = "\(extraPaths):\(env["PATH"] ?? "/usr/bin:/bin")"
        return env
    }

    // MARK: - Temp Screenshot Management

    nonisolated private func saveScreenshotsToTemp(
        images: [(data: Data, label: String)]
    ) -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clicky-codex-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var savedURLs: [URL] = []
        for (index, image) in images.enumerated() {
            let isPNG = image.data.count >= 4 && [UInt8](image.data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47]
            let ext = isPNG ? "png" : "jpg"
            let fileURL = tempDir.appendingPathComponent("screen-\(index).\(ext)")
            try? image.data.write(to: fileURL)
            savedURLs.append(fileURL)
        }
        return savedURLs
    }

    nonisolated private func cleanupTempScreenshots(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clicky-codex-screenshots", isDirectory: true)
        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        if remaining.isEmpty {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Prompt Building

    nonisolated private func buildPrompt(
        screenshotPaths: [URL],
        screenshotLabels: [String],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)],
        userPrompt: String
    ) -> String {
        var parts: [String] = []

        parts.append("<system>\n\(systemPrompt)\n</system>")

        let recentHistory = conversationHistory.suffix(5)
        if !recentHistory.isEmpty {
            parts.append("<conversation_history>")
            for entry in recentHistory {
                parts.append("User: \(entry.userPlaceholder)")
                parts.append("Assistant: \(entry.assistantResponse)")
            }
            parts.append("</conversation_history>")
        }

        if !screenshotPaths.isEmpty {
            parts.append("I've saved screenshots of my screen to these files. Read each one to see what's on my screen:")
            for (index, path) in screenshotPaths.enumerated() {
                let label = index < screenshotLabels.count ? screenshotLabels[index] : "Screen \(index + 1)"
                parts.append("- \(path.path) (\(label))")
            }
        }

        parts.append("\nUser says: \(userPrompt)")
        return parts.joined(separator: "\n\n")
    }

    // MARK: - Analysis (matches ClaudeCLIAdapter signature)

    func analyzeImageStreaming(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String,
        onTextChunk: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        let startTime = Date()

        let screenshotURLs = saveScreenshotsToTemp(images: images)
        let screenshotLabels = images.map { $0.label }

        let prompt = buildPrompt(
            screenshotPaths: screenshotURLs,
            screenshotLabels: screenshotLabels,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            userPrompt: userPrompt
        )

        let codexPath = try resolveBinary()
        let env = buildEnvironment()

        // codex exec runs non-interactively and prints the response
        let args = ["exec", prompt, "--full-auto"]

        print("🔧 [CodexCLI] Executing: \(codexPath)")
        print("   Model: \(model)")
        print("   Screenshots: \(screenshotURLs.count)")

        let result: String = try await withTaskCancellationHandler {
            try await executeProcess(
                codexPath: codexPath,
                arguments: args,
                environment: env
            )
        } onCancel: {
            self.cleanupTempScreenshots(screenshotURLs)
        }

        cleanupTempScreenshots(screenshotURLs)

        let duration = Date().timeIntervalSince(startTime)
        print("✅ [CodexCLI] Response: \(result.count) chars in \(String(format: "%.1f", duration))s")

        await onTextChunk(result)
        return (text: result, duration: duration)
    }

    func analyzeImage(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String
    ) async throws -> (text: String, duration: TimeInterval) {
        return try await analyzeImageStreaming(
            images: images,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            userPrompt: userPrompt,
            onTextChunk: { _ in }
        )
    }

    // MARK: - Process Execution

    /// Codex exec outputs the response as the last line(s) of stdout.
    /// The format is: header lines, then "codex\n<response>\ntokens used\n<count>"
    /// We extract the text between "codex" and "tokens used".
    private func executeProcess(
        codexPath: String,
        arguments: [String],
        environment: [String: String]
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        // Provide empty stdin so codex doesn't wait for input
        process.standardInput = Pipe()

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if !stderr.isEmpty {
                    print("⚠️ [CodexCLI] stderr: \(stderr.prefix(500))")
                }

                guard !hasResumed else { return }
                hasResumed = true

                if proc.terminationStatus == 0 {
                    // Extract response: text between "codex\n" and "\ntokens used"
                    let responseText = Self.extractResponse(from: stdout)
                    if !responseText.isEmpty {
                        continuation.resume(returning: responseText)
                    } else {
                        // Fallback: use the last non-empty line before "tokens used"
                        let lines = stdout.components(separatedBy: "\n")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        let response = lines.last ?? ""
                        if response.isEmpty {
                            continuation.resume(throwing: CodexCLIError.executionFailed("Codex returned empty output"))
                        } else {
                            continuation.resume(returning: response)
                        }
                    }
                } else {
                    if stderr.contains("login") || stderr.contains("auth") || stdout.contains("login") {
                        continuation.resume(throwing: CodexCLIError.notAuthenticated)
                    } else {
                        let errorMsg = stderr.split(separator: "\n").first.map(String.init)
                            ?? "Codex exited with code \(proc.terminationStatus)"
                        continuation.resume(throwing: CodexCLIError.executionFailed(errorMsg))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: CodexCLIError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// Extracts the AI response from Codex exec output.
    /// Format: ...header...\ncodex\n<response text>\ntokens used\n<count>\n<response repeated>
    nonisolated private static func extractResponse(from stdout: String) -> String {
        let lines = stdout.components(separatedBy: "\n")

        // Find "codex" marker, then collect lines until "tokens used"
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

        return responseLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
