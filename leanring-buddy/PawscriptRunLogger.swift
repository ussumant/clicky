//
//  PawscriptRunLogger.swift
//  leanring-buddy
//
//  Durable local run logs for Pawscript extraction, guide, and agent runs.
//

import Foundation

struct PawscriptRunArtifact: Codable, Hashable {
    var kind: String
    var path: String
}

struct PawscriptRunRecord: Codable, Hashable {
    var runId: UUID
    var skillName: String
    var skillTitle: String
    var mode: String
    var sourceURL: String
    var startedAt: Date
    var endedAt: Date?
    var state: String
    var currentStepNumber: Int?
    var currentStepTitle: String?
    var events: [PawscriptExecutionEvent]
    var artifacts: [PawscriptRunArtifact]
    var browserUseExitCode: Int?
    var browserUseOutputTail: String?
    var browserUseStderrTail: String?
    var errorSummary: String?
    var humanCompletions: Int
    var agentCompletions: Int
    var gotchasCount: Int
}

final class PawscriptRunLogger: @unchecked Sendable {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let lock = NSLock()

    private var currentRecord: PawscriptRunRecord?
    private var currentRunDirectory: URL?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    var latestRunURL: URL? {
        lock.lock()
        defer { lock.unlock() }
        return currentRunDirectory
    }

    var runsDirectory: URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseDirectory
            .appendingPathComponent("Pawscript", isDirectory: true)
            .appendingPathComponent("runs", isDirectory: true)
    }

    @discardableResult
    func startRun(
        mode: String,
        package: PawscriptSkillPackage?,
        sourceURL: String,
        currentStep: SkillStep?
    ) -> URL? {
        lock.lock()
        defer { lock.unlock() }

        let runId = UUID()
        let startedAt = Date()
        let skillName = package?.skill.name ?? "no-skill"
        let directoryName = "\(Self.timestampFormatter.string(from: startedAt))-\(Self.slugify(skillName))"
        let runDirectory = runsDirectory.appendingPathComponent(directoryName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: runDirectory, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Pawscript run logger: could not create run directory: \(error.localizedDescription)")
            return nil
        }

        currentRunDirectory = runDirectory
        currentRecord = PawscriptRunRecord(
            runId: runId,
            skillName: skillName,
            skillTitle: package?.skill.title ?? "No skill loaded",
            mode: mode,
            sourceURL: package?.sourceURL ?? sourceURL,
            startedAt: startedAt,
            endedAt: nil,
            state: "running",
            currentStepNumber: currentStep?.number,
            currentStepTitle: currentStep?.title,
            events: [],
            artifacts: [],
            browserUseExitCode: nil,
            browserUseOutputTail: nil,
            browserUseStderrTail: nil,
            errorSummary: nil,
            humanCompletions: package?.skill.humanCompletions ?? 0,
            agentCompletions: package?.skill.agentCompletions ?? 0,
            gotchasCount: package?.gotchas.count ?? 0
        )
        writeCurrentRecordLocked()
        return runDirectory
    }

    func appendEvent(_ event: PawscriptExecutionEvent) {
        lock.lock()
        defer { lock.unlock() }
        currentRecord?.events.append(event)
        writeCurrentRecordLocked()
    }

    func addArtifact(kind: String, path: String) {
        lock.lock()
        defer { lock.unlock() }
        currentRecord?.artifacts.append(PawscriptRunArtifact(kind: kind, path: path))
        writeCurrentRecordLocked()
    }

    func appendProcessOutput(stream: String, text: String) {
        let compactText = Self.stripANSIEscapeCodes(text)
        lock.lock()
        defer { lock.unlock() }
        guard var record = currentRecord else { return }
        switch stream {
        case "stderr":
            record.browserUseStderrTail = Self.tail((record.browserUseStderrTail ?? "") + compactText)
        default:
            record.browserUseOutputTail = Self.tail((record.browserUseOutputTail ?? "") + compactText)
        }
        currentRecord = record
        writeCurrentRecordLocked()
    }

    func updateRun(
        state: String,
        package: PawscriptSkillPackage?,
        currentStep: SkillStep?,
        errorSummary: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard var record = currentRecord else { return }
        record.state = state
        record.currentStepNumber = currentStep?.number
        record.currentStepTitle = currentStep?.title
        record.errorSummary = errorSummary ?? record.errorSummary
        record.humanCompletions = package?.skill.humanCompletions ?? record.humanCompletions
        record.agentCompletions = package?.skill.agentCompletions ?? record.agentCompletions
        record.gotchasCount = package?.gotchas.count ?? record.gotchasCount
        currentRecord = record
        writeCurrentRecordLocked()
    }

    func finishRun(
        state: String,
        package: PawscriptSkillPackage?,
        currentStep: SkillStep?,
        browserUseExitCode: Int? = nil,
        errorSummary: String? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard var record = currentRecord else { return }
        record.endedAt = Date()
        record.state = state
        record.currentStepNumber = currentStep?.number
        record.currentStepTitle = currentStep?.title
        record.browserUseExitCode = browserUseExitCode
        record.errorSummary = errorSummary
        record.humanCompletions = package?.skill.humanCompletions ?? record.humanCompletions
        record.agentCompletions = package?.skill.agentCompletions ?? record.agentCompletions
        record.gotchasCount = package?.gotchas.count ?? record.gotchasCount
        currentRecord = record
        writeCurrentRecordLocked()
    }

    private func writeCurrentRecordLocked() {
        guard let currentRecord, let currentRunDirectory else { return }
        do {
            let data = try encoder.encode(currentRecord)
            try data.write(to: currentRunDirectory.appendingPathComponent("run.json"), options: [.atomic])
        } catch {
            print("⚠️ Pawscript run logger: could not write run.json: \(error.localizedDescription)")
        }
    }

    private static func tail(_ text: String, limit: Int = 12_000) -> String {
        guard text.count > limit else { return text }
        let start = text.index(text.endIndex, offsetBy: -limit)
        return String(text[start...])
    }

    private static func stripANSIEscapeCodes(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"\u001B\[[0-9;]*[A-Za-z]"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func slugify(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let lowercased = text.lowercased()
        var slug = ""
        var lastWasSeparator = false

        for scalar in lowercased.unicodeScalars {
            if allowed.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                slug.append("-")
                lastWasSeparator = true
            }
        }

        let trimmed = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "pawscript-run" : trimmed
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
