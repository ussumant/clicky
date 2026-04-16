//
//  Skill.swift
//  leanring-buddy
//
//  Workflow Recorder-compatible data models for Pawscript skill files.
//  Kept intentionally close to ScreenRecorder's Skill.swift so the same
//  skill shape can be replayed by humans, agents, and Workflow Recorder.
//

import Foundation
import SwiftUI

// MARK: - Skill Difficulty

enum SkillDifficulty: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced

    var label: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var color: Color {
        switch self {
        case .beginner: return Color(hex: "#10B981")
        case .intermediate: return Color(hex: "#F59E0B")
        case .advanced: return Color(hex: "#EF4444")
        }
    }
}

// MARK: - Skill Action

enum SkillAction: String, Codable, CaseIterable {
    case navigate
    case click
    case type
    case select
    case configure
    case verify
    case wait
    case shell
    case conditional

    var icon: String {
        switch self {
        case .navigate: return "safari"
        case .click: return "cursorarrow.click.2"
        case .type: return "keyboard"
        case .select: return "checklist"
        case .configure: return "gearshape"
        case .verify: return "checkmark.shield"
        case .wait: return "clock"
        case .shell: return "terminal"
        case .conditional: return "arrow.triangle.branch"
        }
    }

    var color: Color {
        switch self {
        case .navigate: return Color(hex: "#8B5CF6")
        case .click: return Color(hex: "#3B82F6")
        case .type: return Color(hex: "#10B981")
        case .select: return Color(hex: "#6366F1")
        case .configure: return Color(hex: "#F59E0B")
        case .verify: return Color(hex: "#10B981")
        case .wait: return Color(hex: "#9CA3AF")
        case .shell: return Color(hex: "#EF4444")
        case .conditional: return Color(hex: "#EC4899")
        }
    }

    var label: String {
        switch self {
        case .navigate: return "Navigate"
        case .click: return "Click"
        case .type: return "Type"
        case .select: return "Select"
        case .configure: return "Configure"
        case .verify: return "Verify"
        case .wait: return "Wait"
        case .shell: return "Shell"
        case .conditional: return "Conditional"
        }
    }
}

// MARK: - Skill

struct Skill: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var title: String
    var version: Int
    var yamlContent: String
    var sourceSessionId: UUID?
    var track: String?
    var difficulty: String?
    var estimatedTime: String?
    var confidenceScore: Double
    var humanCompletions: Int
    var agentCompletions: Int
    var agentSuccessRate: Double
    var folderPath: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        title: String,
        version: Int = 1,
        yamlContent: String,
        sourceSessionId: UUID? = nil,
        track: String? = nil,
        difficulty: String? = nil,
        estimatedTime: String? = nil,
        confidenceScore: Double = 0.5,
        humanCompletions: Int = 0,
        agentCompletions: Int = 0,
        agentSuccessRate: Double = 0.0,
        folderPath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.version = version
        self.yamlContent = yamlContent
        self.sourceSessionId = sourceSessionId
        self.track = track
        self.difficulty = difficulty
        self.estimatedTime = estimatedTime
        self.confidenceScore = confidenceScore
        self.humanCompletions = humanCompletions
        self.agentCompletions = agentCompletions
        self.agentSuccessRate = agentSuccessRate
        self.folderPath = folderPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var confidencePercentage: Int {
        Int(confidenceScore * 100)
    }

    var difficultyColor: Color {
        guard let difficulty,
              let level = SkillDifficulty(rawValue: difficulty) else {
            return Color(hex: "#9CA3AF")
        }
        return level.color
    }

    var stepCount: Int {
        let lines = yamlContent.components(separatedBy: .newlines)
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("- step:") || trimmed.hasPrefix("- title:")
        }.count
    }
}

// MARK: - Skill Step

struct SkillStep: Identifiable, Codable, Hashable {
    let id: UUID
    let skillId: UUID
    var number: Int
    var title: String
    var action: String
    var target: String?
    var value: String?
    var description: String
    var verification: String?
    var gotchaText: String?
    var screenshotPath: String?
    var estimatedTime: String?

    init(
        id: UUID = UUID(),
        skillId: UUID,
        number: Int,
        title: String,
        action: String,
        target: String? = nil,
        value: String? = nil,
        description: String,
        verification: String? = nil,
        gotchaText: String? = nil,
        screenshotPath: String? = nil,
        estimatedTime: String? = nil
    ) {
        self.id = id
        self.skillId = skillId
        self.number = number
        self.title = title
        self.action = action
        self.target = target
        self.value = value
        self.description = description
        self.verification = verification
        self.gotchaText = gotchaText
        self.screenshotPath = screenshotPath
        self.estimatedTime = estimatedTime
    }

    var actionType: SkillAction? {
        SkillAction(rawValue: action)
    }
}

// MARK: - Skill Gotcha

struct SkillGotcha: Identifiable, Codable, Hashable {
    let id: UUID
    let skillId: UUID
    var title: String
    var description: String
    var source: String
    var stepNumber: Int?
    var fix: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        skillId: UUID,
        title: String,
        description: String,
        source: String,
        stepNumber: Int? = nil,
        fix: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.title = title
        self.description = description
        self.source = source
        self.stepNumber = stepNumber
        self.fix = fix
        self.createdAt = createdAt
    }
}

// MARK: - Skill Acceptance Criterion

struct SkillAcceptanceCriterion: Identifiable, Codable, Hashable {
    let id: UUID
    let skillId: UUID
    var criterion: String
    var isAutomated: Bool
    var isPassed: Bool?

    init(
        id: UUID = UUID(),
        skillId: UUID,
        criterion: String,
        isAutomated: Bool = false,
        isPassed: Bool? = nil
    ) {
        self.id = id
        self.skillId = skillId
        self.criterion = criterion
        self.isAutomated = isAutomated
        self.isPassed = isPassed
    }
}
