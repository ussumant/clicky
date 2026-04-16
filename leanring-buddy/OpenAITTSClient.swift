//
//  OpenAITTSClient.swift
//  leanring-buddy
//
//  Text-to-speech playback backed by OpenAI's Audio Speech API.
//

import AVFoundation
import Foundation

struct OpenAITTSClientError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

@MainActor
final class OpenAITTSClient {
    private static let speechURL = URL(string: "https://api.openai.com/v1/audio/speech")!

    private let session: URLSession
    private var audioPlayer: AVAudioPlayer?

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    func speakText(_ text: String) async throws {
        guard let apiKey = OpenAISettingsStore.apiKey else {
            throw OpenAITTSClientError(message: "OpenAI TTS is not configured. Add your OpenAI API key in settings.")
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        var request = URLRequest(url: Self.speechURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "model": OpenAISettingsStore.ttsModel,
            "input": String(trimmedText.prefix(4096)),
            "voice": OpenAISettingsStore.ttsVoice,
            "response_format": "mp3"
        ]

        let instructions = OpenAISettingsStore.ttsInstructions
        if !instructions.isEmpty {
            body["instructions"] = instructions
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITTSClientError(message: "OpenAI TTS returned an invalid response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAITTSClientError(message: "OpenAI TTS error (\(httpResponse.statusCode)): \(errorBody)")
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        print("🔊 OpenAI TTS: playing \(data.count / 1024)KB audio with \(OpenAISettingsStore.ttsVoice)")
    }

    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
