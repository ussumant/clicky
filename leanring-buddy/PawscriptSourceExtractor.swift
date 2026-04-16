//
//  PawscriptSourceExtractor.swift
//  leanring-buddy
//
//  Source ingestion for Pawscript. YouTube uses live captions first; docs and
//  failed video validation fall back to the canonical OpenAI frontend guide.
//

import Foundation

final class PawscriptSourceExtractor {
    private let skillStore: PawscriptSkillStore
    private let captionExtractor: PawscriptYouTubeCaptionExtractor
    private let llmSkillExtractor: PawscriptLLMSkillExtractor

    init(
        skillStore: PawscriptSkillStore,
        captionExtractor: PawscriptYouTubeCaptionExtractor = PawscriptYouTubeCaptionExtractor(),
        llmSkillExtractor: PawscriptLLMSkillExtractor = PawscriptLLMSkillExtractor()
    ) {
        self.skillStore = skillStore
        self.captionExtractor = captionExtractor
        self.llmSkillExtractor = llmSkillExtractor
    }

    func extract(kind: PawscriptSourceKind, sourceURL: String) async throws -> PawscriptExtractionResult {
        let normalizedURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .doc:
            if normalizedURL.contains("developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4") {
                let package = try skillStore.loadBundledSkill(named: "openai-delightful-frontends")
                return PawscriptExtractionResult(package: package, fallbackNotice: nil)
            }

            let package = try skillStore.loadBundledSkill(named: "openai-delightful-frontends")
            return PawscriptExtractionResult(
                package: package,
                fallbackNotice: "I loaded the OpenAI frontend guide as a polished doc fallback."
            )

        case .youtube:
            if normalizedURL.contains("Q_bd7BFh0XY") {
                let package = try skillStore.loadBundledSkill(named: "paper-shaders-design-guide")
                return PawscriptExtractionResult(
                    package: package,
                    fallbackNotice: "Loaded the validated Paper Shaders guide for this demo video."
                )
            }

            do {
                let transcript = try await captionExtractor.extractTranscript(from: normalizedURL)
                let package = try await llmSkillExtractor.extractSkill(
                    title: transcript.title,
                    sourceURL: transcript.url,
                    sourceKind: .youtube,
                    transcriptText: transcript.text
                )
                return PawscriptExtractionResult(
                    package: package,
                    fallbackNotice: "Validated live YouTube captions and extracted a browser workflow."
                )
            } catch {
                let package = try skillStore.loadBundledSkill(named: "openai-delightful-frontends")
                return PawscriptExtractionResult(
                    package: package,
                    fallbackNotice: "YouTube validation failed: \(error.localizedDescription). I loaded the doc fallback so the demo can continue."
                )
            }
        }
    }
}
