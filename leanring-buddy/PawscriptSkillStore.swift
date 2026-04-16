//
//  PawscriptSkillStore.swift
//  leanring-buddy
//
//  JSON persistence for Pawscript's hackathon skill packages.
//

import Foundation

enum PawscriptSkillStoreError: LocalizedError {
    case bundledSkillNotFound(String)
    case invalidBundledSkill(String)

    var errorDescription: String? {
        switch self {
        case .bundledSkillNotFound(let name):
            return "Bundled Pawscript skill not found: \(name)"
        case .invalidBundledSkill(let detail):
            return "Invalid Pawscript skill package: \(detail)"
        }
    }
}

final class PawscriptSkillStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    var appSupportDirectory: URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseDirectory.appendingPathComponent("Pawscript", isDirectory: true)
    }

    func loadBundledSkill(named resourceName: String) throws -> PawscriptSkillPackage {
        if let embeddedPackage = Self.makeEmbeddedFallbackSkill(named: resourceName) {
            return embeddedPackage
        }

        guard let resourceURL = bundledSkillURL(named: resourceName) else {
            throw PawscriptSkillStoreError.bundledSkillNotFound(resourceName)
        }
        let data = try Data(contentsOf: resourceURL)
        return try decoder.decode(PawscriptSkillPackage.self, from: data)
    }

    func savePackage(_ package: PawscriptSkillPackage) throws {
        try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        let fileURL = appSupportDirectory.appendingPathComponent("\(package.skill.name).json")
        let data = try encoder.encode(package)
        try data.write(to: fileURL, options: [.atomic])
    }

    func loadSavedPackage(skillName: String) throws -> PawscriptSkillPackage? {
        let fileURL = appSupportDirectory.appendingPathComponent("\(skillName).json")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PawscriptSkillPackage.self, from: data)
    }

    private func bundledSkillURL(named resourceName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "PawscriptSkills"
        ) {
            return url
        }

        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("PawscriptSkills", isDirectory: true)
            .appendingPathComponent("\(resourceName).json") {
            if fileManager.fileExists(atPath: resourceURL.path) {
                return resourceURL
            }
        }

        return nil
    }

    private static func makeEmbeddedFallbackSkill(named resourceName: String) -> PawscriptSkillPackage? {
        switch resourceName {
        case "openai-delightful-frontends":
            return makeOpenAIDelightfulFrontendsSkill()
        case "youtube-codex-tutorial":
            return makeYouTubeCodexTutorialSkill()
        case "paper-shaders-design-guide":
            return makePaperShadersDesignGuideSkill()
        default:
            return nil
        }
    }

    private static func makeOpenAIDelightfulFrontendsSkill() -> PawscriptSkillPackage {
        let skillId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let createdAt = fallbackDate
        let skill = Skill(
            id: skillId,
            name: "openai-delightful-frontends",
            title: "Learn the OpenAI frontend guide",
            yamlContent: """
            name: openai-delightful-frontends
            steps:
              - title: Open the guide
              - title: Find the design constraints
              - title: Inspect the verification advice
              - title: Capture the reusable takeaways
              - title: Verify the learning session
            """,
            track: "frontend",
            difficulty: "beginner",
            estimatedTime: "8min",
            confidenceScore: 0.92,
            folderPath: "embedded/openai-delightful-frontends",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let steps = [
            SkillStep(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222201")!,
                skillId: skillId,
                number: 1,
                title: "Open the guide",
                action: "navigate",
                target: "https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4",
                value: "https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4",
                description: "Open the OpenAI frontend guide in the browser.",
                verification: "The OpenAI guide page is visible.",
                gotchaText: "If the page does not load, use the saved doc fallback summary.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222202")!,
                skillId: skillId,
                number: 2,
                title: "Find design constraints",
                action: "verify",
                target: "Design constraints section",
                description: "Find the part of the guide that explains using explicit visual constraints before building.",
                verification: "The browser is scrolled to guidance about constraints, references, or visual direction.",
                gotchaText: "If the page is long, use browser find for constraint, reference, or visual.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222203")!,
                skillId: skillId,
                number: 3,
                title: "Inspect verification advice",
                action: "verify",
                target: "Verification guidance",
                description: "Find the advice about checking browser screenshots, responsive quality, and avoiding generic UI.",
                verification: "The guide's verification or quality-check guidance is visible.",
                gotchaText: "If verification is not obvious, search the page for screenshot, mobile, or verify.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222204")!,
                skillId: skillId,
                number: 4,
                title: "Capture reusable takeaways",
                action: "verify",
                target: "Guide takeaways",
                description: "Summarize the reusable frontend workflow: define the job, set constraints, build, inspect, then iterate.",
                verification: "The main takeaways are visible or summarized.",
                gotchaText: "Do not treat the doc as passive reading; turn it into a repeatable workflow.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222205")!,
                skillId: skillId,
                number: 5,
                title: "Verify the session",
                action: "verify",
                target: "Learning outcome",
                description: "Confirm the saved doc has become an actionable learning session with steps and gotchas.",
                verification: "Pawscript shows human/agent progress against this same skill.",
                gotchaText: "If the session feels generic, sharpen the extracted targets before automating.",
                estimatedTime: "1min"
            )
        ]

        return PawscriptSkillPackage(
            skill: skill,
            steps: steps,
            gotchas: [
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888801")!,
                    skillId: skillId,
                    title: "Weak prompts create generic UI",
                    description: "If the doc remains passive reading, the user still will not finish it. Convert it into visible browser steps.",
                    source: "doc-fallback-v1",
                    stepNumber: 3,
                    fix: "Extract navigable page sections, visible targets, and concrete verification checks.",
                    createdAt: createdAt
                )
            ],
            criteria: [
                SkillAcceptanceCriterion(
                    id: UUID(uuidString: "99999999-9999-4999-8999-999999999901")!,
                    skillId: skillId,
                    criterion: "The doc can be replayed as a browser learning workflow by a human or Browser Use."
                )
            ],
            prerequisites: [
                PawscriptPrerequisite(
                    id: UUID(uuidString: "77777777-7777-4777-8777-777777777701")!,
                    title: "Use a public browser page",
                    detail: "This fallback is safest when the OpenAI guide is accessible in the browser before Spanks starts pointing or Browser Use starts acting.",
                    kind: "browser-state",
                    source: "doc-fallback-v1",
                    stepNumber: 1,
                    isBlocking: false,
                    actionLabel: "Guide is open"
                )
            ],
            sourceKind: .doc,
            sourceURL: "https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4",
            extractedSummary: "The OpenAI frontend guide becomes an active browser learning session: open the guide, find constraints, inspect verification advice, and capture reusable takeaways.",
            toolsUsed: ["Browser", "OpenAI extraction", "Pawscript screen matching", "Browser Use"],
            promptSnippets: [
                "Turn saved docs into steps with visible browser targets.",
                "Guide the human with screen matching instead of leaving the doc as passive reading.",
                "Use Browser Use to execute the same steps and prove the skill is reusable."
            ],
            customizationQuestion: "What should Spanks help you build with the OpenAI frontend guide?"
        )
    }

    private static func makeYouTubeCodexTutorialSkill() -> PawscriptSkillPackage {
        var package = makeOpenAIDelightfulFrontendsSkill()
        package.skill.name = "youtube-codex-tutorial"
        package.skill.title = "Turn a YouTube tutorial into a Codex run"
        package.skill.track = "codex"
        package.skill.estimatedTime = "6min"
        package.skill.confidenceScore = 0.74
        package.skill.folderPath = "embedded/youtube-codex-tutorial"
        package.sourceKind = .youtube
        package.sourceURL = "https://www.youtube.com/watch?v=C3-4llQYT8o"
        package.extractedSummary = "Cached tutorial extraction for the hackathon demo. It treats the video as a Codex workflow: identify the goal, translate the tutorial into a prompt, run Codex, inspect results, and save gotchas."
        package.customizationQuestion = "What should Spanks adapt from this video tutorial to your current project?"
        package.toolsUsed = ["YouTube tutorial", "yt-dlp fallback detection", "Codex CLI", "Pawscript cached skill"]
        package.promptSnippets = [
            "Convert the tutorial into a practical Codex execution plan.",
            "Ask the user for the target use case before running the generated prompt.",
            "Record any places where the tutorial assumed missing context."
        ]
        return package
    }

    private static func makePaperShadersDesignGuideSkill() -> PawscriptSkillPackage {
        let skillId = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        let createdAt = fallbackDate
        let skill = Skill(
            id: skillId,
            name: "paper-shaders-design-guide",
            title: "Use Paper Shaders with Browser Use handoff",
            yamlContent: """
            name: paper-shaders-design-guide
            steps:
              - title: Open an editable Paper canvas
              - title: Handle login or canvas handoff
              - title: Add or select Warp shader
              - title: Choose and tune a preset
              - title: Freeze motion or export React
              - title: Add Fluted Glass image filter
              - title: Chain Halftone if useful
              - title: Vectorize and verify final asset
            """,
            track: "design",
            difficulty: "beginner",
            estimatedTime: "10min",
            confidenceScore: 0.86,
            folderPath: "PawscriptSkills/paper-shaders-design-guide.json",
            createdAt: createdAt,
            updatedAt: createdAt
        )

        let steps = [
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666601")!,
                skillId: skillId,
                number: 1,
                title: "Open an editable Paper canvas",
                action: "navigate",
                target: "https://shaders.paper.design",
                value: "https://shaders.paper.design",
                description: "Navigate to Paper Shaders, then look for an action that opens the shader in Paper or an editable Paper canvas. If the screen is a marketing page only, use the most direct visible open, try, remix, or copy-to-Paper action.",
                verification: "Continue only when an editable canvas or shader editor is visible. If not, hand off to the user and resume after they open the canvas.",
                gotchaText: "If the browser lands on login, signup, pricing, or a static gallery, pause and ask the user to open an editable Paper canvas.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666602")!,
                skillId: skillId,
                number: 2,
                title: "Handle login or canvas handoff",
                action: "conditional",
                target: "Paper editor state",
                value: "Pause if confidence is below 0.75",
                description: "Check whether the user is signed in and whether a canvas with shader controls is visible. If account, file, or canvas setup blocks progress, ask the user to complete it manually.",
                verification: "The next screen has an editable canvas, a selected object, or visible shader controls. If the user corrected the screen, continue from that state.",
                gotchaText: "Do not attempt to create accounts, enter private credentials, or change billing settings.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666603")!,
                skillId: skillId,
                number: 3,
                title: "Add or select Warp shader",
                action: "select",
                target: "Warp shader",
                value: "Warp",
                description: "Find a Warp shader in the current canvas or shader library. If a Warp shader is already selected, keep it. Otherwise, add or open Warp from the visible shader list.",
                verification: "A Warp or comparable generative shader is selected and its preset or parameter controls are visible.",
                gotchaText: "If Warp is not visible, choose the first available abstract or generative shader and tell the user what changed.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666604")!,
                skillId: skillId,
                number: 4,
                title: "Choose and tune a preset",
                action: "configure",
                target: "Presets and shader parameter controls",
                value: "Pick one preset, then adjust 1-2 controls",
                description: "Open the preset control, choose a visually distinct preset, then adjust one or two obvious parameters such as scale, intensity, shape, spacing, or distortion. Move fast, but do not drag unknown controls repeatedly.",
                verification: "The selected shader visibly changes from the starting preset, and the canvas still looks usable.",
                gotchaText: "If a slider label or control purpose is unclear, make one small adjustment and verify the visual change before continuing.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666605")!,
                skillId: skillId,
                number: 5,
                title: "Freeze motion or export React",
                action: "configure",
                target: "Speed control or Copy as React",
                value: "Speed 0 or Copy as React",
                description: "If a Speed control is visible, set it to zero when the user wants a static texture. If an export menu or Copy as React button is visible, copy the shader code. If export is hidden, skip export and continue after noting it.",
                verification: "Either motion is intentionally set, React code has been copied, or the step was skipped with a clear note.",
                gotchaText: "Do not get stuck hunting for export. The core guide can continue without a React copy.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666606")!,
                skillId: skillId,
                number: 6,
                title: "Add Fluted Glass image filter",
                action: "configure",
                target: "Fluted Glass image input",
                value: "Fluted Glass",
                description: "Add or select the Fluted Glass image filter. Use Edit to upload an image, the eyedropper to capture a visible image, or Paper image generation if available. Pause for user correction if the image source is ambiguous.",
                verification: "An image appears inside the Fluted Glass shader and the filter visibly changes the image.",
                gotchaText: "Image upload and eyedropper selection are likely handoff points. Ask the user to pick the image if the target is not obvious.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666607")!,
                skillId: skillId,
                number: 7,
                title: "Chain Halftone if useful",
                action: "configure",
                target: "Halftone shader or vintage preset",
                value: "Halftone or Vintage",
                description: "If the filtered image looks stable, add a Halftone shader or choose a visible halftone or vintage preset. Skip this step if the canvas is already visually busy.",
                verification: "The added shader makes the graphic more distinctive without obscuring the image. If not, undo or ask the user whether to keep it.",
                gotchaText: "The correct fast move is sometimes to skip the extra shader. Ask the user if the result is already good enough.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666608")!,
                skillId: skillId,
                number: 8,
                title: "Vectorize and verify final asset",
                action: "verify",
                target: "Vectorize and final asset",
                value: "Vectorize if visible",
                description: "If a flat generated image is selected and Vectorize is visible in the context menu, run Vectorize. Otherwise skip vectorization and verify the final asset format with the user.",
                verification: "The user confirms the result and export path: live shader, static texture, React code, or SVG.",
                gotchaText: "Right-click context menus are brittle for browser agents. If Vectorize is not visible immediately, ask the user to open it or skip.",
                estimatedTime: "2min"
            )
        ]

        return PawscriptSkillPackage(
            skill: skill,
            steps: steps,
            gotchas: [
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888803")!,
                    skillId: skillId,
                    title: "Do not stop at presets",
                    description: "Presets are useful starting points, but a design can feel generic if the preset is not tuned.",
                    source: "youtube-captions-v1",
                    stepNumber: 2,
                    fix: "Choose a preset, then adjust parameters until the shader supports the specific graphic.",
                    createdAt: createdAt
                ),
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888804")!,
                    skillId: skillId,
                    title: "Layer effects carefully",
                    description: "Chained shaders can become visually noisy when every layer is strong.",
                    source: "youtube-captions-v1",
                    stepNumber: 6,
                    fix: "Reduce the strength of one shader or return to the original image and apply only the strongest effect.",
                    createdAt: createdAt
                ),
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888805")!,
                    skillId: skillId,
                    title: "Use handoff when UI confidence drops",
                    description: "The Paper editor, shader library, and export menu may expose different UI labels depending on account state or product changes.",
                    source: "browser-use-hardening",
                    stepNumber: 1,
                    fix: "If the agent cannot identify the target control with high confidence, pause and ask the user to click the correct control, then continue from the resulting screen.",
                    createdAt: createdAt
                )
            ],
            criteria: [
                SkillAcceptanceCriterion(
                    id: UUID(uuidString: "99999999-9999-4999-8999-999999999903")!,
                    skillId: skillId,
                    criterion: "A Browser Use agent can complete the public steps, pause for login or low-confidence UI states, and hand control back to the user for correction without losing progress."
                )
            ],
            prerequisites: [
                PawscriptPrerequisite(
                    id: UUID(uuidString: "77777777-7777-4777-8777-777777777703")!,
                    title: "Paper editor access",
                    detail: "The video operates inside the Paper editor. If the browser shows marketing, signup, login, or an empty workspace instead of an editable canvas, pause and ask the user to sign in or open a canvas.",
                    kind: "login",
                    source: "youtube-captions-v1",
                    stepNumber: 1,
                    isBlocking: true,
                    actionLabel: "Signed in"
                ),
                PawscriptPrerequisite(
                    id: UUID(uuidString: "77777777-7777-4777-8777-777777777704")!,
                    title: "Prepare an image source",
                    detail: "Have an image ready to upload, or let the user approve a generated image before the agent pulls it into the image-filter shader.",
                    kind: "asset",
                    source: "youtube-captions-v1",
                    stepNumber: 6,
                    isBlocking: false,
                    actionLabel: "Image ready"
                ),
                PawscriptPrerequisite(
                    id: UUID(uuidString: "77777777-7777-4777-8777-777777777705")!,
                    title: "Confirm correction handoff",
                    detail: "Tell the user that the agent will move quickly through obvious UI states, but will pause when it cannot confidently identify a button, shader control, image source, or export menu.",
                    kind: "safety",
                    source: "browser-use-hardening",
                    stepNumber: 1,
                    isBlocking: false,
                    actionLabel: "Fast handoff OK"
                )
            ],
            sourceKind: .youtube,
            sourceURL: "https://www.youtube.com/watch?v=Q_bd7BFh0XY",
            extractedSummary: "The Paper Shaders walkthrough becomes a browser-agent workflow: open Paper Shaders, enter an editable Paper canvas, pause for login or missing editor state, place a Warp shader, choose and tune a preset, export React code, add a Fluted Glass image filter, hand off if image capture is ambiguous, chain a Halftone shader, and optionally vectorize a flat image.",
            toolsUsed: ["Paper", "Paper Shaders", "Shader presets", "Image generation", "Eyedropper image capture", "Copy as React", "Vectorize"],
            promptSnippets: [
                "Move fast through visible Paper controls, but pause for human correction when confidence is below 0.75 or the screen differs from the expected state.",
                "If Paper asks for login, signup, payment, or project selection, stop and ask the user to complete that step manually.",
                "Prefer visible labels: Warp, Presets, Speed, Copy as React, Fluted Glass, Edit, eyedropper, Halftone, Vintage, Vectorize.",
                "After every material canvas change, verify the visible result before continuing.",
                "If image capture, shader chaining, or export is ambiguous, ask the user to click or select the target, then resume from the new screen."
            ],
            customizationQuestion: "What kind of graphic should Spanks help you make with Paper Shaders, and should the agent move fast or pause before changing the canvas?"
        )
    }

    private static var fallbackDate: Date {
        ISO8601DateFormatter().date(from: "2026-04-16T00:00:00Z") ?? Date()
    }
}
