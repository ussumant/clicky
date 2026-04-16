//
//  PawscriptContextCapture.swift
//  leanring-buddy
//
//  Saves screenshots and lightweight context whenever Pawscript gets stuck.
//

import Foundation

enum PawscriptContextCaptureError: LocalizedError {
    case noScreenCapture

    var errorDescription: String? {
        switch self {
        case .noScreenCapture:
            return "Could not capture a Pawscript stuck screenshot."
        }
    }
}

struct PawscriptContextSnapshot {
    let screenshotPath: String
    let contextPath: String
}

final class PawscriptContextCapture {
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    @MainActor
    func capture(
        package: PawscriptSkillPackage,
        step: SkillStep?,
        reason: String,
        eventMessage: String,
        source: String
    ) async throws -> PawscriptContextSnapshot {
        let captures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
        guard let focusCapture = captures.first(where: { $0.isCursorScreen }) ?? captures.first else {
            throw PawscriptContextCaptureError.noScreenCapture
        }

        let directory = try snapshotDirectory(for: package)
        let timestamp = Self.fileTimestamp.string(from: Date())
        let basename = "stuck-\(step?.number ?? 0)-\(timestamp)"
        let screenshotURL = directory.appendingPathComponent("\(basename).jpg")
        let contextURL = directory.appendingPathComponent("\(basename).json")

        try focusCapture.imageData.write(to: screenshotURL, options: [.atomic])

        let context = PawscriptCapturedContext(
            createdAt: Date(),
            skillName: package.skill.name,
            skillTitle: package.skill.title,
            sourceURL: package.sourceURL,
            source: source,
            reason: reason,
            eventMessage: eventMessage,
            stepNumber: step?.number,
            stepTitle: step?.title,
            stepAction: step?.action,
            stepTarget: step?.target,
            stepDescription: step?.description,
            screenshotPath: screenshotURL.path
        )
        let data = try encoder.encode(context)
        try data.write(to: contextURL, options: [.atomic])

        return PawscriptContextSnapshot(
            screenshotPath: screenshotURL.path,
            contextPath: contextURL.path
        )
    }

    private func snapshotDirectory(for package: PawscriptSkillPackage) throws -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pawscript", isDirectory: true)
            .appendingPathComponent("stuck-context", isDirectory: true)
            .appendingPathComponent(package.skill.name, isDirectory: true)
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        return baseDirectory
    }

    private static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private struct PawscriptCapturedContext: Codable {
    var createdAt: Date
    var skillName: String
    var skillTitle: String
    var sourceURL: String
    var source: String
    var reason: String
    var eventMessage: String
    var stepNumber: Int?
    var stepTitle: String?
    var stepAction: String?
    var stepTarget: String?
    var stepDescription: String?
    var screenshotPath: String
}
