//
//  LocalTTSClient.swift
//  leanring-buddy
//
//  Local text-to-speech using macOS AVSpeechSynthesizer. No network
//  required — runs entirely on device. Drop-in replacement for
//  ElevenLabsTTSClient with the same interface.
//

import AVFoundation
import Foundation

@MainActor
final class LocalTTSClient: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    /// The voice identifier to use. Premium Siri voices sound significantly
    /// better than the default system voice. Falls back gracefully if the
    /// preferred voice is not installed.
    private let preferredVoiceIdentifier: String

    /// Tracks whether speech is currently playing.
    private(set) var isPlaying: Bool = false

    /// Continuation for the async speakText method — resumed when speech
    /// finishes or is cancelled.
    private var speakContinuation: CheckedContinuation<Void, Never>?

    init(preferredVoiceIdentifier: String = "com.apple.voice.premium.en-US.Zoe") {
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text` using the local macOS speech synthesizer.
    /// Returns once speech begins (matching ElevenLabsTTSClient behavior).
    func speakText(_ text: String) async throws {
        stopPlayback()

        try Task.checkCancellation()

        let utterance = AVSpeechUtterance(string: text)
        // Slightly slower than default for a more natural, conversational feel
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        // Pre/post utterance silence for natural pacing
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.1

        // Try voices in quality order: premium → enhanced → Siri compact → default
        utterance.voice = LocalTTSClient.bestAvailableVoice(preferred: preferredVoiceIdentifier)

        isPlaying = true
        synthesizer.speak(utterance)
        print("🔊 Local TTS: speaking \(text.count) chars with \(utterance.voice?.name ?? "default") voice")
    }

    /// Stops any in-progress playback immediately.
    func stopPlayback() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
        speakContinuation?.resume()
        speakContinuation = nil
    }

    /// Waits until the current speech finishes. Used by scheduleTransientHideIfNeeded.
    func waitUntilFinished() async {
        guard isPlaying else { return }
        await withCheckedContinuation { continuation in
            self.speakContinuation = continuation
        }
    }

    // MARK: - Voice Selection

    /// Selects the best available English voice, preferring high-quality voices.
    /// Priority: preferred identifier → premium voices → enhanced → Siri compact → any English.
    private static func bestAvailableVoice(preferred: String) -> AVSpeechSynthesisVoice? {
        // Try the exact preferred voice first
        if let voice = AVSpeechSynthesisVoice(identifier: preferred) {
            return voice
        }

        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.starts(with: "en") }

        // Premium quality (best)
        if let premium = englishVoices.first(where: { $0.quality == .premium }) {
            return premium
        }

        // Enhanced quality (good)
        if let enhanced = englishVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }

        // Siri compact voices (better than generic defaults)
        let siriVoices = englishVoices.filter { $0.identifier.contains("siri") }
        if let siri = siriVoices.first(where: { $0.language == "en-US" }) ?? siriVoices.first {
            return siri
        }

        // Any en-US voice
        return englishVoices.first(where: { $0.language == "en-US" }) ?? englishVoices.first
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.speakContinuation?.resume()
            self.speakContinuation = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.speakContinuation?.resume()
            self.speakContinuation = nil
        }
    }
}
