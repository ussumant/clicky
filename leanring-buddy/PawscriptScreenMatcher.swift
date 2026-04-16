//
//  PawscriptScreenMatcher.swift
//  leanring-buddy
//
//  Matches the current Pawscript step against the live screen and returns
//  coordinates for Spanks + cursor guidance.
//

import Foundation

enum PawscriptScreenMatcherError: LocalizedError {
    case openAIKeyMissing
    case noScreenCapture
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .openAIKeyMissing:
            return "OpenAI key missing; add it in settings for live screen matching."
        case .noScreenCapture:
            return "Could not capture the screen for Pawscript guidance."
        case .invalidResponse:
            return "Screen matcher returned an invalid response."
        }
    }
}

final class PawscriptScreenMatcher {
    @MainActor
    func match(step: SkillStep) async throws -> PawscriptScreenMatch {
        guard let apiKey = OpenAISettingsStore.apiKey else {
            throw PawscriptScreenMatcherError.openAIKeyMissing
        }

        let captures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
        guard let focusCapture = captures.first(where: { $0.isCursorScreen }) ?? captures.first else {
            throw PawscriptScreenMatcherError.noScreenCapture
        }

        let api = OpenAIAPI(apiKey: apiKey, model: "gpt-4o-mini")
        let prompt = """
        You are Pawscript's screen matcher.
        Current skill step:
        title: \(step.title)
        action: \(step.action)
        target: \(step.target ?? "unknown")
        value: \(step.value ?? "none")
        instruction: \(step.description)
        verification: \(step.verification ?? "none")

        Look at the screenshot. Return ONLY JSON:
        {
          "state": "on_it|ahead|stuck|wrong_app|unknown",
          "confidence": 0.0,
          "hint": "short spoken hint",
          "x": 123,
          "y": 456
        }

        Coordinates are in screenshot pixels, top-left origin. If there is no target, use null for x and y.
        """

        let (text, _) = try await api.analyzeImage(
            images: [(data: focusCapture.imageData, label: "current screen")],
            systemPrompt: "Return compact JSON only. No markdown.",
            userPrompt: prompt
        )

        guard let jsonData = extractJSONObject(from: text).data(using: .utf8),
              let raw = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw PawscriptScreenMatcherError.invalidResponse
        }

        let state = raw["state"] as? String ?? "unknown"
        let confidence = raw["confidence"] as? Double ?? 0.0
        let hint = raw["hint"] as? String ?? step.description
        let screenshotX = raw["x"] as? Double
        let screenshotY = raw["y"] as? Double

        let mappedCoordinate: (x: Double, y: Double)?
        if let screenshotX, let screenshotY {
            let displayX = screenshotX * Double(focusCapture.displayWidthInPoints) / Double(max(1, focusCapture.screenshotWidthInPixels))
            let displayYTopLeft = screenshotY * Double(focusCapture.displayHeightInPoints) / Double(max(1, focusCapture.screenshotHeightInPixels))
            let appKitY = Double(focusCapture.displayHeightInPoints) - displayYTopLeft
            mappedCoordinate = (
                x: Double(focusCapture.displayFrame.minX) + displayX,
                y: Double(focusCapture.displayFrame.minY) + appKitY
            )
        } else {
            mappedCoordinate = nil
        }

        return PawscriptScreenMatch(
            state: state,
            confidence: confidence,
            hint: hint,
            x: mappedCoordinate?.x,
            y: mappedCoordinate?.y,
            screenIndex: 0
        )
    }

    private func extractJSONObject(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[start...end])
    }
}
