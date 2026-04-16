//
//  PawscriptYouTubeCaptionExtractor.swift
//  leanring-buddy
//
//  Live YouTube caption extraction for Pawscript. yt-dlp is intentionally
//  required rather than auto-installed so the hackathon demo setup is explicit.
//

import Foundation

enum PawscriptYouTubeCaptionExtractorError: LocalizedError {
    case ytDLPNotFound
    case captionsUnavailable(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .ytDLPNotFound:
            return "yt-dlp is not installed. Install it before the demo with `brew install yt-dlp`."
        case .captionsUnavailable(let detail):
            return "YouTube captions unavailable: \(detail)"
        case .commandFailed(let detail):
            return "yt-dlp failed: \(detail)"
        }
    }
}

final class PawscriptYouTubeCaptionExtractor {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func extractTranscript(from sourceURL: String) async throws -> PawscriptYouTubeTranscript {
        let ytDLPPath = try resolveYTDLP()
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("pawscript-captions-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let title = (try? await runYTDLP(
            path: ytDLPPath,
            arguments: ["--skip-download", "--print", "%(title)s", sourceURL]
        ).trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 } ?? "YouTube tutorial"

        _ = try await runYTDLP(
            path: ytDLPPath,
            arguments: [
                "--skip-download",
                "--write-subs",
                "--write-auto-subs",
                "--sub-langs", "en.*",
                "--sub-format", "vtt",
                "-o", tempDirectory.appendingPathComponent("captions.%(ext)s").path,
                sourceURL
            ]
        )

        let captionFiles = try fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        )
            .filter { $0.pathExtension.lowercased() == "vtt" }

        guard let captionFile = captionFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).first else {
            throw PawscriptYouTubeCaptionExtractorError.captionsUnavailable("No English VTT captions were downloaded.")
        }

        let vttText = try String(contentsOf: captionFile, encoding: .utf8)
        let transcriptText = Self.parseVTT(vttText)
        guard transcriptText.count > 160 else {
            throw PawscriptYouTubeCaptionExtractorError.captionsUnavailable("Caption text was too short to extract a reliable workflow.")
        }

        return PawscriptYouTubeTranscript(title: title, url: sourceURL, text: transcriptText)
    }

    private func resolveYTDLP() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "\(NSHomeDirectory())/.local/bin/yt-dlp"
        ]

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return candidate
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["yt-dlp"]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try? process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !output.isEmpty && fileManager.isExecutableFile(atPath: output) {
            return output
        }

        throw PawscriptYouTubeCaptionExtractorError.ytDLPNotFound
    }

    private func runYTDLP(path: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.environment = buildEnvironment()

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let output = String(
                    data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let errorOutput = String(
                    data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let detail = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: PawscriptYouTubeCaptionExtractorError.commandFailed(detail.isEmpty ? output : detail))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: PawscriptYouTubeCaptionExtractorError.commandFailed(error.localizedDescription))
            }
        }
    }

    private func buildEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:\(NSHomeDirectory())/.local/bin"
        environment["PATH"] = "\(extraPaths):\(environment["PATH"] ?? "/usr/bin:/bin")"
        return environment
    }

    private static func parseVTT(_ vttText: String) -> String {
        var seen = Set<String>()
        let lines = vttText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                guard !line.isEmpty else { return false }
                guard line != "WEBVTT" else { return false }
                guard !line.contains("-->") else { return false }
                guard !line.hasPrefix("NOTE") else { return false }
                guard Int(line) == nil else { return false }
                return true
            }
            .map { line in
                line
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { line in
                guard !line.isEmpty, !seen.contains(line) else { return false }
                seen.insert(line)
                return true
            }

        return lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
