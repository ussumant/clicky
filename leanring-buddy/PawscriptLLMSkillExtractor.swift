//
//  PawscriptLLMSkillExtractor.swift
//  leanring-buddy
//
//  Converts tutorial text into WR-compatible skill packages.
//

import Foundation

enum PawscriptLLMSkillExtractorError: LocalizedError {
    case openAIKeyMissing
    case unsafeOrNonBrowserWorkflow(String)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .openAIKeyMissing:
            return "Add your OpenAI API key in settings before extracting live tutorial skills."
        case .unsafeOrNonBrowserWorkflow(let detail):
            return "This source is not a safe browser workflow for the demo: \(detail)"
        case .invalidResponse:
            return "The skill extractor returned an invalid response."
        case .apiError(let detail):
            return "OpenAI skill extraction failed: \(detail)"
        }
    }
}

final class PawscriptLLMSkillExtractor {
    private struct SkillExtractionResponse: Decodable {
        struct Step: Decodable {
            let title: String
            let action: String
            let target: String?
            let value: String?
            let description: String
            let verification: String?
            let gotchaText: String?
            let estimatedTime: String?
        }

        struct Prerequisite: Decodable {
            let title: String
            let detail: String
            let kind: String?
            let source: String?
            let stepNumber: Int?
            let isBlocking: Bool?
            let actionLabel: String?
        }

        let title: String
        let summary: String
        let isBrowserWorkflow: Bool
        let unsafeReasons: [String]
        let prerequisites: [Prerequisite]?
        let toolsUsed: [String]
        let promptSnippets: [String]
        let steps: [Step]
    }

    private let session: URLSession
    private let model: String

    init(model: String = "gpt-4o-mini") {
        self.model = model

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: configuration)
    }

    func extractSkill(
        title sourceTitle: String,
        sourceURL: String,
        sourceKind: PawscriptSourceKind,
        transcriptText: String
    ) async throws -> PawscriptSkillPackage {
        guard let apiKey = OpenAISettingsStore.apiKey else {
            throw PawscriptLLMSkillExtractorError.openAIKeyMissing
        }

        let response = try await requestExtraction(
            apiKey: apiKey,
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            sourceKind: sourceKind,
            transcriptText: transcriptText
        )

        guard response.isBrowserWorkflow else {
            throw PawscriptLLMSkillExtractorError.unsafeOrNonBrowserWorkflow(
                response.unsafeReasons.isEmpty ? "No browser workflow was detected." : response.unsafeReasons.joined(separator: "; ")
            )
        }

        guard !response.steps.isEmpty else {
            throw PawscriptLLMSkillExtractorError.invalidResponse
        }

        let skillId = UUID()
        let skillName = slugify(response.title)
        let steps = response.steps.prefix(8).enumerated().map { index, step in
            SkillStep(
                skillId: skillId,
                number: index + 1,
                title: step.title,
                action: normalizeAction(step.action),
                target: step.target,
                value: step.value,
                description: step.description,
                verification: step.verification,
                gotchaText: step.gotchaText,
                estimatedTime: step.estimatedTime
            )
        }

        let yamlSteps = steps.map { "  - title: \($0.title)\n    action: \($0.action)" }.joined(separator: "\n")
        let skill = Skill(
            id: skillId,
            name: skillName,
            title: response.title,
            yamlContent: "name: \(skillName)\nsteps:\n\(yamlSteps)\n",
            track: "browser-workflow",
            difficulty: "beginner",
            estimatedTime: "\(max(3, steps.count * 2))min",
            confidenceScore: 0.82,
            folderPath: "Pawscript/live/\(skillName)",
            createdAt: Date(),
            updatedAt: Date()
        )

        let extractionGotchas = response.unsafeReasons.prefix(2).map { reason in
            SkillGotcha(
                skillId: skillId,
                title: "Extraction note",
                description: reason,
                source: sourceKind == .youtube ? "youtube-captions-v1" : "doc-extraction-v1"
            )
        }
        var prerequisites = (response.prerequisites ?? []).map { prerequisite in
            PawscriptPrerequisite(
                title: prerequisite.title,
                detail: prerequisite.detail,
                kind: prerequisite.kind ?? "setup",
                source: prerequisite.source ?? (sourceKind == .youtube ? "youtube-captions-v1" : "doc-extraction-v1"),
                stepNumber: prerequisite.stepNumber,
                isBlocking: prerequisite.isBlocking ?? true,
                actionLabel: prerequisite.actionLabel
            )
        }
        prerequisites.append(contentsOf: inferPrerequisites(
            sourceKind: sourceKind,
            transcriptText: transcriptText,
            steps: steps,
            existing: prerequisites
        ))

        return PawscriptSkillPackage(
            skill: skill,
            steps: steps,
            gotchas: extractionGotchas,
            criteria: [
                SkillAcceptanceCriterion(
                    skillId: skillId,
                    criterion: "The browser workflow can be guided for a human and executed by Browser Use."
                )
            ],
            prerequisites: prerequisites,
            sourceKind: sourceKind,
            sourceURL: sourceURL,
            extractedSummary: response.summary,
            toolsUsed: response.toolsUsed.isEmpty ? ["YouTube captions", "OpenAI extraction", "Browser Use"] : response.toolsUsed,
            promptSnippets: response.promptSnippets,
            customizationQuestion: "What should Spanks help you do with this saved tutorial?"
        )
    }

    private func requestExtraction(
        apiKey: String,
        sourceTitle: String,
        sourceURL: String,
        sourceKind: PawscriptSourceKind,
        transcriptText: String
    ) async throws -> SkillExtractionResponse {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let clippedTranscript = String(transcriptText.prefix(18_000))
        let systemPrompt = """
        You extract safe browser-workflow tutorials into Workflow Recorder-compatible steps.
        Return only JSON. No markdown.
        Accept browser workflows that are demo-safe. If a tutorial assumes the user is already signed in or has a free account, keep isBrowserWorkflow=true and record that as a blocking prerequisite instead of silently folding it into a step.
        Reject workflows that require payment, purchases, private credentials, destructive actions, account setting changes, real customer data, or irreversible submissions.
        Allowed actions: navigate, click, type, select, configure, verify, wait, conditional.
        Treat hidden tutorial assumptions as first-class prerequisites: login state, required account/app, sample asset, browser/profile state, demo-safe data, existing project, permissions, or installed extension.
        Never interpret a 404, page-not-found, empty DOM, or stale URL as a login requirement. Record stale or uncertain URLs as gotchas, not login prerequisites.
        """
        let userPrompt = """
        Source kind: \(sourceKind.label)
        Source title: \(sourceTitle)
        Source URL: \(sourceURL)

        Extract a short executable browser skill from this tutorial.
        If this is not a safe browser workflow, set isBrowserWorkflow=false and explain unsafeReasons.

        JSON shape:
        {
          "title": "short skill title",
          "summary": "one sentence",
          "isBrowserWorkflow": true,
          "unsafeReasons": [],
          "prerequisites": [
            {
              "title": "Sign in to Example",
              "detail": "The tutorial starts after login; ask the user to sign in before automation continues.",
              "kind": "login|account|asset|permission|browser-state|data|setup|safety",
              "source": "youtube-captions-v1",
              "stepNumber": 1,
              "isBlocking": true,
              "actionLabel": "I'm signed in"
            }
          ],
          "toolsUsed": ["..."],
          "promptSnippets": ["..."],
          "steps": [
            {
              "title": "short",
              "action": "navigate|click|type|select|configure|verify|wait|conditional",
              "target": "visible UI target or URL",
              "value": "text/URL/value or null",
              "description": "plain instruction",
              "verification": "how to know it worked",
              "gotchaText": "likely stuck point",
              "estimatedTime": "1min"
            }
          ]
        }

        Prerequisite rules:
        - If the source says or implies "open your dashboard", "your account", "after signing in", "create a new project", or starts inside an authenticated app, add a blocking login/account prerequisite.
        - Only add login prerequisites when the tutorial itself implies authentication. Do not infer login from a failed URL, 404, or blank page.
        - If an image/file/demo asset is needed, add an asset prerequisite.
        - If a workflow is safe after the user completes a private step manually, keep the executable public/safe steps and put the private step in prerequisites.
        - Do not include login/password/private information as executable steps.

        Transcript/content:
        \(clippedTranscript)
        """

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PawscriptLLMSkillExtractorError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PawscriptLLMSkillExtractorError.apiError(String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw PawscriptLLMSkillExtractorError.invalidResponse
        }

        return try JSONDecoder().decode(SkillExtractionResponse.self, from: contentData)
    }

    private func normalizeAction(_ rawAction: String) -> String {
        let normalized = rawAction.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return SkillAction(rawValue: normalized)?.rawValue ?? "verify"
    }

    private func inferPrerequisites(
        sourceKind: PawscriptSourceKind,
        transcriptText: String,
        steps: [SkillStep],
        existing: [PawscriptPrerequisite]
    ) -> [PawscriptPrerequisite] {
        let combinedText = (
            transcriptText + "\n" + steps.map { "\($0.title) \($0.description) \($0.target ?? "") \($0.value ?? "")" }.joined(separator: "\n")
        ).lowercased()
        var inferred: [PawscriptPrerequisite] = []

        let hasSessionCue = [
            "sign in",
            "signed in",
            "log in",
            "logged in",
            "account",
            "dashboard",
            "workspace",
            "editor",
            "project",
            "your site",
            "your app"
        ].contains { combinedText.contains($0) }

        if hasSessionCue && !hasExistingPrerequisite(kind: "account", in: existing) {
            inferred.append(PawscriptPrerequisite(
                title: "Open the tutorial app in a ready session",
                detail: "This tutorial appears to assume an existing account, workspace, editor, project, or signed-in session. Spanks should pause so you can sign in or open a safe demo workspace before automation continues.",
                kind: "account",
                source: sourceKind == .youtube ? "youtube-captions-v1" : "doc-extraction-v1",
                stepNumber: 1,
                isBlocking: true,
                actionLabel: "Session is ready"
            ))
        }

        let hasAssetCue = [
            "upload",
            "source image",
            "image file",
            "sample image",
            "choose file",
            "drag in"
        ].contains { combinedText.contains($0) }

        if hasAssetCue && !hasExistingPrerequisite(kind: "asset", in: existing) {
            inferred.append(PawscriptPrerequisite(
                title: "Prepare a demo-safe asset",
                detail: "The workflow may need a sample image or file. Have a harmless demo asset ready before Browser Use reaches the upload step.",
                kind: "asset",
                source: sourceKind == .youtube ? "youtube-captions-v1" : "doc-extraction-v1",
                stepNumber: steps.first { $0.action == "click" && ($0.target ?? "").lowercased().contains("upload") }?.number,
                isBlocking: true,
                actionLabel: "Asset is ready"
            ))
        }

        return inferred
    }

    private func hasExistingPrerequisite(kind: String, in prerequisites: [PawscriptPrerequisite]) -> Bool {
        prerequisites.contains { $0.kind.lowercased() == kind.lowercased() }
    }

    private func slugify(_ title: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "pawscript-live-skill" : slug
    }
}
