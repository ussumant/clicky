//
//  PawscriptPromptBuilder.swift
//  leanring-buddy
//
//  Converts a WR-format skill into a Codex-ready execution prompt.
//

import Foundation

struct PawscriptPromptBuilder {
    func buildPrompt(
        package: PawscriptSkillPackage,
        userGoal: String,
        mode: PawscriptExecutionMode
    ) -> String {
        let trimmedGoal = userGoal.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = trimmedGoal.isEmpty
            ? "Build a small, polished frontend demo that proves the tutorial guidance."
            : trimmedGoal

        let steps = package.steps
            .sorted { $0.number < $1.number }
            .map { step in
                [
                    "\(step.number). \(step.title)",
                    "Action: \(step.action)",
                    step.target.map { "Target: \($0)" },
                    step.value.map { "Value: \($0)" },
                    "Instruction: \(step.description)",
                    step.verification.map { "Verification: \($0)" },
                    step.gotchaText.map { "Gotcha: \($0)" }
                ]
                    .compactMap { $0 }
                    .joined(separator: "\n")
            }
            .joined(separator: "\n\n")

        let tools = package.toolsUsed.isEmpty
            ? "Codex CLI, browser preview, screenshot/manual verification"
            : package.toolsUsed.joined(separator: ", ")

        return """
        You are Codex executing a Pawscript skill generated from a tutorial source.

        User goal:
        \(goal)

        Skill:
        \(package.skill.title)

        Source:
        \(package.sourceURL)

        Tools expected:
        \(tools)

        Execution mode:
        \(mode.label)

        Rules:
        - Work only in the current working directory.
        - Create or update a small demo app/page that satisfies the user goal.
        - Prefer simple, dependency-light implementation unless the project already has a stack.
        - Use the tutorial's design/process guidance, but adapt it to the user's goal.
        - If a decision is subjective, choose a strong default and briefly explain it.
        - Do not touch secrets, credentials, or system settings.
        - At the end, summarize what changed and how to preview it.

        Tutorial-derived steps:
        \(steps)

        Prompt snippets from the source:
        \(package.promptSnippets.map { "- \($0)" }.joined(separator: "\n"))
        """
    }
}
