//
//  PawscriptBrowserUseExecutor.swift
//  leanring-buddy
//
//  Runs Browser Use against the same WR-compatible skill used for human guidance.
//

import Foundation

enum PawscriptBrowserUseExecutorError: LocalizedError {
    case openAIKeyMissing
    case pythonNotFound
    case runnerNotFound
    case executionFailed(String, Int32)

    var errorDescription: String? {
        switch self {
        case .openAIKeyMissing:
            return "OpenAI key missing; add it in settings before running Browser Use."
        case .pythonNotFound:
            return "Python environment not found. Preinstall Browser Use in `.venv` or set PAWSCRIPT_PYTHON."
        case .runnerNotFound:
            return "Pawscript Browser Use runner was not found in the app bundle."
        case .executionFailed(let detail, let exitCode):
            return "Browser Use execution failed (\(exitCode)): \(detail)"
        }
    }

    var exitCode: Int32? {
        if case .executionFailed(_, let exitCode) = self {
            return exitCode
        }
        return nil
    }
}

struct PawscriptBrowserUseExecutionResult {
    var output: String
}

final class PawscriptBrowserUseExecutor {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let controlLock = NSLock()
    private var activeControlDirectory: URL?
    private var activeProcess: Process?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func run(
        package: PawscriptSkillPackage,
        userGoal: String,
        runLogger: PawscriptRunLogger? = nil,
        onEvent: @escaping (PawscriptBrowserUseEvent) -> Void
    ) async throws -> PawscriptBrowserUseExecutionResult {
        guard let apiKey = OpenAISettingsStore.apiKey else {
            throw PawscriptBrowserUseExecutorError.openAIKeyMissing
        }

        let pythonPath = try resolvePython()
        let runnerURL = try resolveRunnerScript()
        let payloadURL = try writePayload(package: package, userGoal: userGoal)
        let controlDirectory = try makeControlDirectory()
        let browserProfileDirectory = try makeBrowserProfileDirectory()
        runLogger?.addArtifact(kind: "browser-control", path: controlDirectory.path)
        runLogger?.addArtifact(kind: "browser-profile", path: browserProfileDirectory.path)
        runLogger?.addArtifact(kind: "chrome-debug-port", path: "9339")

        let output = try await runProcess(
            pythonPath: pythonPath,
            runnerURL: runnerURL,
            payloadURL: payloadURL,
            openAIKey: apiKey,
            controlDirectory: controlDirectory,
            browserProfileDirectory: browserProfileDirectory,
            runLogger: runLogger,
            onEvent: onEvent
        )

        return PawscriptBrowserUseExecutionResult(output: output)
    }

    func continueAfterHumanHelp(note: String = "The user resolved the visible blocker.") {
        writeControlSignal(named: "resume.json", note: note)
    }

    func stopRunningProcess(note: String = "Stopped by user.") {
        writeControlSignal(named: "stop.json", note: note)
        controlLock.lock()
        let process = activeProcess
        controlLock.unlock()
        if process?.isRunning == true {
            process?.terminate()
        }
    }

    private func writePayload(package: PawscriptSkillPackage, userGoal: String) throws -> URL {
        let payload: [String: Any] = [
            "userGoal": userGoal,
            "skill": try JSONSerialization.jsonObject(with: encoder.encode(package))
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        let payloadURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pawscript-browser-use-\(UUID().uuidString).json")
        try payloadData.write(to: payloadURL, options: [.atomic])
        return payloadURL
    }

    private func makeControlDirectory() throws -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pawscript", isDirectory: true)
            .appendingPathComponent("browser-use-control", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeBrowserProfileDirectory() throws -> URL {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pawscript", isDirectory: true)
            .appendingPathComponent("browser-profile", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeControlSignal(named fileName: String, note: String) {
        controlLock.lock()
        let directory = activeControlDirectory
        controlLock.unlock()

        guard let directory else { return }
        let payload: [String: String] = [
            "note": note,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
            try data.write(to: directory.appendingPathComponent(fileName), options: [.atomic])
        } catch {
            print("⚠️ Pawscript Browser Use control signal failed: \(error.localizedDescription)")
        }
    }

    private func resolvePython() throws -> String {
        let envPython = ProcessInfo.processInfo.environment["PAWSCRIPT_PYTHON"]
        let candidates = [
            envPython,
            FileManager.default.currentDirectoryPath + "/.venv/bin/python",
            NSHomeDirectory() + "/dev/personalos/Coding/companion-clicky/.venv/bin/python",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ].compactMap { $0 }

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        throw PawscriptBrowserUseExecutorError.pythonNotFound
    }

    private func resolveRunnerScript() throws -> URL {
        if let bundleURL = Bundle.main.url(
            forResource: "pawscript_browser_agent",
            withExtension: "py",
            subdirectory: "PawscriptScripts"
        ) {
            return bundleURL
        }

        if let bundleURL = Bundle.main.url(
            forResource: "pawscript_browser_agent",
            withExtension: "py"
        ) {
            return bundleURL
        }

        if let explicitRunnerPath = ProcessInfo.processInfo.environment["PAWSCRIPT_RUNNER_PATH"],
           FileManager.default.isReadableFile(atPath: explicitRunnerPath) {
            return URL(fileURLWithPath: explicitRunnerPath)
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("leanring-buddy", isDirectory: true)
            .appendingPathComponent("PawscriptScripts", isDirectory: true)
            .appendingPathComponent("pawscript_browser_agent.py")
        if FileManager.default.fileExists(atPath: repoURL.path) {
            return repoURL
        }

        let knownDevelopmentURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("dev/personalos/Coding/companion-clicky/leanring-buddy/PawscriptScripts/pawscript_browser_agent.py")
        if FileManager.default.fileExists(atPath: knownDevelopmentURL.path) {
            return knownDevelopmentURL
        }

        throw PawscriptBrowserUseExecutorError.runnerNotFound
    }

    private func runProcess(
        pythonPath: String,
        runnerURL: URL,
        payloadURL: URL,
        openAIKey: String,
        controlDirectory: URL,
        browserProfileDirectory: URL,
        runLogger: PawscriptRunLogger?,
        onEvent: @escaping (PawscriptBrowserUseEvent) -> Void
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let state = BrowserUseProcessState()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [runnerURL.path, payloadURL.path]
            process.environment = buildEnvironment(
                openAIKey: openAIKey,
                controlDirectory: controlDirectory,
                browserProfileDirectory: browserProfileDirectory
            )

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            setActiveProcess(process, controlDirectory: controlDirectory)

            @Sendable func resumeOnce(_ result: Result<String, Error>) {
                guard state.markResumed() else { return }
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                self.clearActiveProcess(process)
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                state.appendOutput(text)
                runLogger?.appendProcessOutput(stream: "stdout", text: text)
                for line in text.components(separatedBy: .newlines) {
                    guard let lineData = line.data(using: .utf8),
                          let event = try? JSONDecoder().decode(PawscriptBrowserUseEvent.self, from: lineData) else {
                        continue
                    }
                    onEvent(event)
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8) else { return }
                state.appendError(text)
                runLogger?.appendProcessOutput(stream: "stderr", text: text)
            }

            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                let remainingStderr = String(
                    data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                if !remainingStderr.isEmpty {
                    state.appendError(remainingStderr)
                    runLogger?.appendProcessOutput(stream: "stderr", text: remainingStderr)
                }

                if process.terminationStatus == 0 {
                    resumeOnce(.success(state.output.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    let stderr = state.errorOutput
                    let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Browser Use exited with code \(process.terminationStatus)"
                        : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    resumeOnce(.failure(PawscriptBrowserUseExecutorError.executionFailed(detail, process.terminationStatus)))
                }
            }

            do {
                try process.run()
            } catch {
                resumeOnce(.failure(PawscriptBrowserUseExecutorError.executionFailed(error.localizedDescription, -1)))
            }
        }
    }

    private func setActiveProcess(_ process: Process, controlDirectory: URL) {
        controlLock.lock()
        activeProcess = process
        activeControlDirectory = controlDirectory
        controlLock.unlock()
    }

    private func clearActiveProcess(_ process: Process) {
        controlLock.lock()
        if activeProcess === process {
            activeProcess = nil
            activeControlDirectory = nil
        }
        controlLock.unlock()
    }

    private func buildEnvironment(
        openAIKey: String,
        controlDirectory: URL,
        browserProfileDirectory: URL
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin"
        environment["PATH"] = "\(extraPaths):\(environment["PATH"] ?? "/usr/bin:/bin")"
        environment["OPENAI_API_KEY"] = openAIKey
        environment["BROWSER_USE_HEADLESS"] = "false"
        environment["PAWSCRIPT_CONTROL_DIR"] = controlDirectory.path
        environment["PAWSCRIPT_BROWSER_PROFILE_DIR"] = browserProfileDirectory.path
        environment["PAWSCRIPT_CHROME_DEBUG_PORT"] = "9339"
        return environment
    }
}

private final class BrowserUseProcessState {
    private let lock = NSLock()
    private var outputBuffer = ""
    private var errorBuffer = ""
    private var hasResumed = false

    var output: String {
        lock.lock()
        defer { lock.unlock() }
        return outputBuffer
    }

    func appendOutput(_ text: String) {
        lock.lock()
        outputBuffer += text
        lock.unlock()
    }

    var errorOutput: String {
        lock.lock()
        defer { lock.unlock() }
        return errorBuffer
    }

    func appendError(_ text: String) {
        lock.lock()
        errorBuffer += text
        lock.unlock()
    }

    func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else { return false }
        hasResumed = true
        return true
    }
}
