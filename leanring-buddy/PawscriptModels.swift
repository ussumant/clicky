//
//  PawscriptModels.swift
//  leanring-buddy
//
//  Small Pawscript-specific wrappers around Workflow Recorder skill models.
//

import Foundation

enum PawscriptSourceKind: String, CaseIterable, Codable {
    case youtube
    case doc

    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .doc: return "Doc"
        }
    }

    var placeholder: String {
        switch self {
        case .youtube: return "Paste a YouTube tutorial URL"
        case .doc: return "Paste a how-to doc URL"
        }
    }
}

enum PawscriptExecutionMode: String, CaseIterable, Codable {
    case watchMe
    case copyIntoCodex
    case doTogether

    var label: String {
        switch self {
        case .watchMe: return "Watch Spanks do it"
        case .copyIntoCodex: return "Copy into Codex"
        case .doTogether: return "Guide me"
        }
    }
}

enum PawscriptRunState: Equatable {
    case idle
    case extracting
    case ready
    case running
    case paused
    case waitingForHuman(String)
    case completed
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .extracting: return "Extracting"
        case .ready: return "Skill loaded"
        case .running: return "Running"
        case .paused: return "Paused"
        case .waitingForHuman: return "Needs help"
        case .completed: return "Complete"
        case .failed: return "Needs fallback"
        }
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

struct PawscriptSkillPackage: Codable, Hashable {
    var skill: Skill
    var steps: [SkillStep]
    var gotchas: [SkillGotcha]
    var criteria: [SkillAcceptanceCriterion]
    var prerequisites: [PawscriptPrerequisite]?
    var sourceKind: PawscriptSourceKind
    var sourceURL: String
    var extractedSummary: String
    var toolsUsed: [String]
    var promptSnippets: [String]
    var customizationQuestion: String

    var currentYamlContent: String {
        skill.yamlContent
    }

    var effectivePrerequisites: [PawscriptPrerequisite] {
        let explicit = prerequisites ?? []
        guard explicit.isEmpty else { return explicit }

        let combinedText = (
            extractedSummary + "\n" + steps.map { "\($0.title) \($0.description) \($0.target ?? "") \($0.value ?? "")" }.joined(separator: "\n")
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

        if hasSessionCue {
            inferred.append(PawscriptPrerequisite(
                id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA1")!,
                title: "Open the tutorial app in a ready session",
                detail: "This saved tutorial appears to assume an existing account, workspace, editor, project, or signed-in session. Sign in or open a safe demo workspace before Spanks automates it.",
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

        if hasAssetCue {
            inferred.append(PawscriptPrerequisite(
                id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAA2")!,
                title: "Prepare a demo-safe asset",
                detail: "This workflow may need a sample image or file. Have a harmless demo asset ready before Browser Use reaches the upload step.",
                kind: "asset",
                source: sourceKind == .youtube ? "youtube-captions-v1" : "doc-extraction-v1",
                stepNumber: steps.first { $0.action == "click" && ($0.target ?? "").lowercased().contains("upload") }?.number,
                isBlocking: true,
                actionLabel: "Asset is ready"
            ))
        }

        return inferred
    }

    var blockingPrerequisites: [PawscriptPrerequisite] {
        effectivePrerequisites.filter(\.isBlocking)
    }
}

struct PawscriptPrerequisite: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var kind: String
    var source: String
    var stepNumber: Int?
    var isBlocking: Bool
    var actionLabel: String?

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        kind: String,
        source: String,
        stepNumber: Int? = nil,
        isBlocking: Bool = true,
        actionLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.source = source
        self.stepNumber = stepNumber
        self.isBlocking = isBlocking
        self.actionLabel = actionLabel
    }
}

struct PawscriptExtractionResult {
    var package: PawscriptSkillPackage
    var fallbackNotice: String?
}

struct PawscriptScreenMatch: Codable, Hashable {
    var state: String
    var confidence: Double
    var hint: String
    var x: Double?
    var y: Double?
    var screenIndex: Int

    var hasCoordinate: Bool {
        x != nil && y != nil
    }
}

struct PawscriptYouTubeTranscript {
    var title: String
    var url: String
    var text: String
}

struct PawscriptBrowserUseEvent: Codable, Hashable {
    var type: String
    var message: String
    var stepNumber: Int?
    var screenshotPath: String?
    var contextPath: String?
}

struct PawscriptExecutionEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, detail: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}
