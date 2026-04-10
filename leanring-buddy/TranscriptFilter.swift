//
//  TranscriptFilter.swift
//  leanring-buddy
//
//  Post-processing filters for voice transcripts. Removes ASR artifacts,
//  filler words, and verbal disfluencies before the transcript reaches Claude.
//  Ported from Muesli's FillerWordFilter + TranscriptionEngineArtifactsFilter.
//

import Foundation

// MARK: - Transcript Filter (combines artifact removal + filler word stripping)

struct TranscriptFilter {

    /// Full post-processing pipeline: artifacts → fillers → cleanup.
    static func apply(_ text: String) -> String {
        let afterArtifacts = TranscriptionArtifactsFilter.apply(text)
        let afterFillers = FillerWordFilter.apply(afterArtifacts)
        return afterFillers
    }
}

// MARK: - Filler Word Filter

/// Removes filler words and verbal disfluencies from transcribed text.
/// Ported from Muesli's FillerWordFilter.swift.
private struct FillerWordFilter {

    /// Single filler words to remove (matched case-insensitively as whole words).
    private static let fillers: Set<String> = [
        "uh", "um", "uh,", "um,", "uhh", "umm",
        "er", "err", "ah", "ahh",
        "hmm", "hm", "mm", "mmm",
        "like,",   // "like" as filler only when followed by comma
    ]

    /// Multi-word filler phrases to remove.
    private static let fillerPhrases: [String] = [
        "you know,",
        "i mean,",
        "sort of",
        "kind of",
    ]

    static func apply(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text

        // Phase 1: Remove multi-word filler phrases (case-insensitive)
        for phrase in fillerPhrases {
            while let range = result.range(of: phrase, options: .caseInsensitive) {
                result.replaceSubrange(range, with: "")
            }
        }

        // Phase 2: Remove single filler words
        let words = result.components(separatedBy: " ")
        let filtered = words.filter { word in
            !fillers.contains(word.lowercased())
        }
        result = filtered.joined(separator: " ")

        // Clean up: collapse multiple spaces, trim
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        result = result.trimmingCharacters(in: .whitespaces)

        // Re-capitalize sentence start after removal
        if let first = result.first, first.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }

        return result
    }
}

// MARK: - Transcription Artifacts Filter

/// Removes known model hallucination artifacts emitted on silence or blank input.
/// Ported from Muesli's TranscriptionEngineArtifactsFilter.swift.
private struct TranscriptionArtifactsFilter {

    private static let artifacts: Set<String> = [
        "[blank_audio]",
    ]

    private static let promptLeakPatterns: [String] = [
        #"(?i)\btranscribe the spoken audio accurately\.?"#,
        #"(?i)\bif a word is unclear,?\s*use the most likely word that fits well within the context of the overall sentence(?:\s+transcription)?\.?"#,
    ]

    static func apply(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if artifacts.contains(trimmed.lowercased()) {
            return ""
        }

        var result = trimmed
        for pattern in promptLeakPatterns {
            // Strip from start
            result = result.replacingOccurrences(
                of: #"^\s*(?:"# + pattern + #")(?:\s+|$)"#,
                with: " ",
                options: .regularExpression
            )
            // Strip from end
            result = result.replacingOccurrences(
                of: #"(?:^|\s+)(?:"# + pattern + #")\s*$"#,
                with: " ",
                options: .regularExpression
            )
        }

        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
