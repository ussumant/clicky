//
//  ClaudeCLIAdapter.swift
//  leanring-buddy
//
//  Claude Code CLI adapter for Clicky. Routes chat requests through the
//  locally-installed `claude` binary instead of the Anthropic API, so usage
//  bills against the user's existing Claude subscription (no API key needed).
//
//  Pattern source: ScreenRecorder/ClaudeAnalysisService.swift
//  (Paperclip adapter pattern: @paperclipai/adapter-claude-local)
//

import Foundation

// MARK: - Configuration

struct ClaudeCLIConfig {
    var command: String = "claude"
    var model: String = "claude-sonnet-4-6"
    var timeoutSeconds: Int = 120

    /// Candidate paths for the Claude binary
    static let binaryCandidates = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "\(NSHomeDirectory())/.local/bin/claude",
        "\(NSHomeDirectory())/.npm-global/bin/claude",
        "\(NSHomeDirectory())/.claude/local/claude"
    ]
}

// MARK: - Errors

enum ClaudeCLIError: LocalizedError {
    case binaryNotFound
    case notAuthenticated
    case executionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "Claude Code CLI not found. Install: npm install -g @anthropic-ai/claude-code"
        case .notAuthenticated:
            return "Claude CLI not authenticated. Run 'claude auth login' in your terminal."
        case .executionFailed(let detail):
            return "Claude CLI error: \(detail)"
        case .timeout:
            return "Claude CLI timed out"
        }
    }
}

// MARK: - Stream JSON Event Types (matching Claude CLI output)

private struct CLIStreamEvent: Codable {
    let type: String?
    let subtype: String?
    let message: CLIStreamMessage?
}

private struct CLIStreamMessage: Codable {
    let content: [CLIStreamContent]?
}

private struct CLIStreamContent: Codable {
    let type: String?
    let text: String?
}

// MARK: - ClaudeCLIAdapter

/// Routes chat requests through the locally-installed Claude Code CLI binary.
/// The CLI handles authentication using the user's cached subscription credentials
/// from ~/.claude, so no API key management is needed.
@MainActor
final class ClaudeCLIAdapter {

    private var config: ClaudeCLIConfig

    init(config: ClaudeCLIConfig = ClaudeCLIConfig()) {
        self.config = config
    }

    /// The model used for CLI requests. Updated by CompanionManager when the
    /// user switches models in the panel picker.
    var model: String {
        get { config.model }
        set { config.model = newValue }
    }

    // MARK: - Binary Resolution (Paperclip pattern: ensureCommandResolvable)

    /// Returns true if the Claude CLI binary can be found on this machine.
    func isCLIAvailable() -> Bool {
        return (try? resolveBinary()) != nil
    }

    nonisolated private func resolveBinary() throws -> String {
        // Check known candidate paths first
        for path in ClaudeCLIConfig.binaryCandidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: which claude
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["claude"]
        let pipe = Pipe()
        which.standardOutput = pipe
        try? which.run()
        which.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        throw ClaudeCLIError.binaryNotFound
    }

    // MARK: - Environment (Paperclip pattern: ensurePathInEnv)

    nonisolated private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/usr/local/bin:/opt/homebrew/bin:\(NSHomeDirectory())/.local/bin"
        env["PATH"] = "\(extraPaths):\(env["PATH"] ?? "/usr/bin:/bin")"
        return env
    }

    // MARK: - Temp Screenshot Management

    /// Saves image data to temp files so the Claude CLI can read them via its
    /// built-in Read tool. Returns the file URLs for cleanup after the response.
    nonisolated private func saveScreenshotsToTemp(
        images: [(data: Data, label: String)]
    ) -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clicky-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var savedURLs: [URL] = []
        for (index, image) in images.enumerated() {
            // Detect format from magic bytes
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
        // Remove the temp directory if empty
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clicky-screenshots", isDirectory: true)
        let remaining = (try? FileManager.default.contentsOfDirectory(atPath: tempDir.path)) ?? []
        if remaining.isEmpty {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - Prompt Building

    /// Formats conversation history and screenshot paths into a single prompt
    /// for the stateless `-p` CLI invocation.
    nonisolated private func buildPrompt(
        screenshotPaths: [URL],
        screenshotLabels: [String],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)],
        userPrompt: String
    ) -> String {
        var parts: [String] = []

        // System instructions
        parts.append("<system>\n\(systemPrompt)\n</system>")

        // Conversation history (cap at last 5 exchanges to keep prompt size reasonable)
        let recentHistory = conversationHistory.suffix(5)
        if !recentHistory.isEmpty {
            parts.append("<conversation_history>")
            for entry in recentHistory {
                parts.append("User: \(entry.userPlaceholder)")
                parts.append("Assistant: \(entry.assistantResponse)")
            }
            parts.append("</conversation_history>")
        }

        // Screenshots — tell Claude to read the temp files
        if !screenshotPaths.isEmpty {
            parts.append("I've saved screenshots of my screen to these files. Read each one to see what's on my screen:")
            for (index, path) in screenshotPaths.enumerated() {
                let label = index < screenshotLabels.count ? screenshotLabels[index] : "Screen \(index + 1)"
                parts.append("- \(path.path) (\(label))")
            }
        }

        // User's actual question/transcript
        parts.append("\nUser says: \(userPrompt)")

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Streaming Analysis (matches ClaudeAPI.analyzeImageStreaming signature)

    /// Sends a vision request through the Claude CLI with streaming output.
    /// Saves screenshots to temp files, spawns the CLI process, and parses
    /// stream-json events to deliver progressive text chunks via onTextChunk.
    func analyzeImageStreaming(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String,
        onTextChunk: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        let startTime = Date()

        // Save screenshots to temp files for the CLI to read
        let screenshotURLs = saveScreenshotsToTemp(images: images)
        let screenshotLabels = images.map { $0.label }

        let prompt = buildPrompt(
            screenshotPaths: screenshotURLs,
            screenshotLabels: screenshotLabels,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            userPrompt: userPrompt
        )

        let claudePath = try resolveBinary()
        let env = buildEnvironment()

        // Build CLI arguments:
        // -p: print mode (non-interactive, single prompt)
        // --output-format stream-json: JSON events on stdout for streaming
        // --model: which Claude model to use
        // --bare: skip hooks, LSP, CLAUDE.md auto-discovery for fast startup
        // --dangerously-skip-permissions: let CLI read temp screenshot files without prompting
        var args = [
            "-p", prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--model", config.model,
            "--dangerously-skip-permissions"
        ]

        // Allow the Read tool so CLI can view the saved screenshots
        args += ["--allowedTools", "Read"]

        print("🔧 [ClaudeCLI] Executing: \(claudePath)")
        print("   Model: \(config.model)")
        print("   Screenshots: \(screenshotURLs.count)")
        print("   Prompt length: \(prompt.count) chars")

        let result: String = try await withTaskCancellationHandler {
            try await executeStreamingProcess(
                claudePath: claudePath,
                arguments: args,
                environment: env,
                onTextChunk: onTextChunk
            )
        } onCancel: {
            // Cleanup temp files even if the task is cancelled
            self.cleanupTempScreenshots(screenshotURLs)
        }

        // Cleanup temp screenshots
        cleanupTempScreenshots(screenshotURLs)

        let duration = Date().timeIntervalSince(startTime)
        print("✅ [ClaudeCLI] Response: \(result.count) chars in \(String(format: "%.1f", duration))s")
        return (text: result, duration: duration)
    }

    /// Non-streaming variant for simple requests.
    func analyzeImage(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String
    ) async throws -> (text: String, duration: TimeInterval) {
        // Use the streaming version but ignore chunks
        return try await analyzeImageStreaming(
            images: images,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            userPrompt: userPrompt,
            onTextChunk: { _ in }
        )
    }

    // MARK: - Process Execution with Streaming

    /// Spawns the Claude CLI as a subprocess and parses stream-json output
    /// line by line, calling onTextChunk for each new text delta.
    private func executeStreamingProcess(
        claudePath: String,
        arguments: [String],
        environment: [String: String],
        onTextChunk: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            var accumulatedText = ""
            var rawStdout = ""
            var lastSentText = ""
            var hasResumed = false

            // Stream stdout line-by-line, parsing stream-json events
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }

                // Parse each complete line as a JSON event
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    rawStdout += chunkString
                    for rawLine in chunkString.split(separator: "\n", omittingEmptySubsequences: true) {
                        let line = rawLine.trimmingCharacters(in: .whitespaces)
                        guard !line.isEmpty,
                              let lineData = line.data(using: .utf8),
                              let event = try? JSONDecoder().decode(CLIStreamEvent.self, from: lineData) else {
                            continue
                        }

                        // Extract text from assistant message events
                        if event.type == "assistant",
                           let contents = event.message?.content {
                            for block in contents where block.type == "text" {
                                if let text = block.text, !text.isEmpty {
                                    accumulatedText = text
                                }
                            }
                        }

                        // Send accumulated text to UI if it changed
                        if accumulatedText != lastSentText {
                            lastSentText = accumulatedText
                            let textToSend = accumulatedText
                            DispatchQueue.main.async {
                                onTextChunk(textToSend)
                            }
                        }
                    }
                }
            }

            process.terminationHandler = { proc in
                // Stop streaming handler and drain remaining bytes
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty,
                   let remainingString = String(data: remaining, encoding: .utf8) {
                    for rawLine in remainingString.split(separator: "\n", omittingEmptySubsequences: true) {
                        let line = rawLine.trimmingCharacters(in: .whitespaces)
                        guard let lineData = line.data(using: .utf8),
                              let event = try? JSONDecoder().decode(CLIStreamEvent.self, from: lineData) else {
                            continue
                        }
                        if event.type == "assistant",
                           let contents = event.message?.content {
                            for block in contents where block.type == "text" {
                                if let text = block.text, !text.isEmpty {
                                    accumulatedText = text
                                }
                            }
                        }
                    }
                }

                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                guard !hasResumed else { return }
                hasResumed = true

                // Log stderr for debugging
                if !stderr.isEmpty {
                    print("⚠️ [ClaudeCLI] stderr: \(stderr.prefix(500))")
                }

                if proc.terminationStatus == 0 && !accumulatedText.isEmpty {
                    continuation.resume(returning: accumulatedText)
                } else if proc.terminationStatus == 0 && accumulatedText.isEmpty {
                    // Check stdout for auth errors in stream-json output
                    let stdout = rawStdout
                    if stdout.contains("authentication_failed") || stdout.contains("Not logged in") {
                        print("⚠️ [ClaudeCLI] Auth failed — run 'claude auth login' in terminal")
                        continuation.resume(throwing: ClaudeCLIError.notAuthenticated)
                    } else {
                        print("⚠️ [ClaudeCLI] Empty output. stdout: \(stdout.prefix(300))")
                        continuation.resume(throwing: ClaudeCLIError.executionFailed("Claude returned empty output"))
                    }
                } else {
                    // Check for auth errors in stderr or stdout
                    let stdout = rawStdout
                    if stderr.contains("auth") || stderr.contains("login") || stdout.contains("authentication_failed") {
                        continuation.resume(throwing: ClaudeCLIError.notAuthenticated)
                    } else {
                        let errorMsg = stderr.split(separator: "\n").first.map(String.init)
                            ?? "Claude exited with code \(proc.terminationStatus)"
                        print("⚠️ [ClaudeCLI] Exit \(proc.terminationStatus): \(errorMsg)")
                        continuation.resume(throwing: ClaudeCLIError.executionFailed(errorMsg))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(throwing: ClaudeCLIError.executionFailed(error.localizedDescription))
            }
        }
    }
}
