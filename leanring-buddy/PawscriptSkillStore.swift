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
            title: "Create an Ask AI shader card in Paper",
            yamlContent: """
            name: paper-shaders-design-guide
            steps:
              - title: Open an editable Paper canvas
              - title: Handle login or canvas handoff
              - title: Draw the rounded card and inner circle
              - title: Add the Liquid Metal shader
              - title: Add a sparkle icon and Ask AI text
              - title: Apply Neuron Noise to the text
              - title: Add and tune the Pulsing Border
              - title: Verify the final social graphic
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
                target: "https://paper.design/",
                value: "https://paper.design/",
                description: "Navigate to Paper, then open a signed-in editable Paper canvas before adding shader effects. If the screen is marketing, signup, login, or an empty workspace, hand off to the user to open the correct canvas.",
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
                title: "Draw the rounded card and inner circle",
                action: "configure",
                target: "Rectangle tool, Fill, Radius, Width, Height",
                value: "Card: 520x180, radius 44, fill #151515. Circle: 116x116, fill #2F7DFF, x near left edge, vertically centered.",
                description: "Use the rectangle tool to create one card-sized rounded rectangle. Set it to roughly 520 by 180, radius about 44, and dark fill #151515. Add one 116 by 116 circle or rounded square on the left, centered vertically. If exact numeric inputs are not visible, use the closest visual size.",
                verification: "A single dark rounded card is visible with one blue circular placeholder on its left side.",
                gotchaText: "Paper's layers feel reversed compared with Figma: lower items in the layers panel can appear visually above. If the circle disappears, check layer order.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666604")!,
                skillId: skillId,
                number: 4,
                title: "Add the Liquid Metal shader",
                action: "configure",
                target: "Shaders panel, Liquid Metal shader, opacity/background control",
                value: "Liquid Metal on the left circle; background opacity 0 if visible.",
                description: "Open the shaders/effects panel and select Liquid Metal. Place it over the blue left circle. Set any visible background opacity to 0, keep the shader circular, and resize it to stay inside the left circle. If Liquid Metal is unavailable, use the first metal-looking shader and continue.",
                verification: "The left circle area now shows a metallic shader texture inside the card.",
                gotchaText: "If Liquid Metal is not visible by exact name, choose the most obvious metal shader and keep moving.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666605")!,
                skillId: skillId,
                number: 5,
                title: "Add a sparkle icon and Ask AI text",
                action: "configure",
                target: "Text tool and any sparkle/star icon",
                value: "Text: Ask AI, white, 44px if possible. Icon: white sparkle/star, 40px, left of text.",
                description: "Add the exact text 'Ask AI' in white, around 44px, centered vertically in the card to the right of the circle. Add any sparkle/star icon in white, about 40px, immediately left of the text. If icon import is slow, draw a simple star or skip the icon after saying so.",
                verification: "The card reads Ask AI in white, with a sparkle/star icon or placeholder beside it.",
                gotchaText: "If importing SVG is slow, skip the icon import and use any visible sparkle/star icon already available.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666606")!,
                skillId: skillId,
                number: 6,
                title: "Apply Neuron Noise to the text",
                action: "configure",
                target: "Neuron Noise shader, blending mode, color controls",
                value: "Neuron Noise over text, Blend: Multiply, Scale: about 2, Brightness: about 70%.",
                description: "Add Neuron Noise over the Ask AI text only. Set blend mode to Multiply if visible. Set scale near 2 and brightness near 70% if controls exist. Use a blue color and a gray color if color pickers are visible. If controls are hidden, make one visible noise/text change and advance.",
                verification: "The Ask AI text has a subtle blue-gray shader/noise treatment while remaining readable.",
                gotchaText: "Do not over-tune. Apply one visible Neuron Noise treatment and advance.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666607")!,
                skillId: skillId,
                number: 7,
                title: "Add and tune the Pulsing Border",
                action: "configure",
                target: "Pulsing Border shader, roundness, opacity, color controls",
                value: "Pulsing Border around card; Roundness 100%; background opacity 0; colors blue/green.",
                description: "Add Pulsing Border around the outside of the card. Set roundness to 100% or maximum, set background opacity to 0 if visible, resize it to match the card bounds, then set red/orange colors to blue or green if color controls are visible.",
                verification: "A pulsing or glowing rounded border frames the card without covering the icon or Ask AI text.",
                gotchaText: "If color controls are not visible, keep the default border and advance. The key visible payoff is the border framing the card.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666608")!,
                skillId: skillId,
                number: 8,
                title: "Verify the final social graphic",
                action: "verify",
                target: "Final Paper canvas",
                value: "Ask AI shader card",
                description: "Compare the result to the tutorial target: dark rounded card, metallic circle, sparkle icon, Ask AI text, subtle text shader, and pulsing border. Ask the user whether to keep it as a live Paper design or export later.",
                verification: "The user can point to the finished Ask AI-style graphic on the Paper canvas.",
                gotchaText: "Do not chase export in the live demo. The win is that the saved YouTube tutorial became an active guided session.",
                estimatedTime: "1min"
            )
        ]

        return PawscriptSkillPackage(
            skill: skill,
            steps: steps,
            gotchas: [
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888803")!,
                    skillId: skillId,
                    title: "Paper layer order feels reversed",
                    description: "The tutorial notes that elements below in Paper's layers panel may appear above visually, which can surprise Figma users.",
                    source: "youtube-captions-v1",
                    stepNumber: 3,
                    fix: "If the metal shader, circle, or card disappears, inspect layer order before changing the design.",
                    createdAt: createdAt
                ),
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888804")!,
                    skillId: skillId,
                    title: "Icon sourcing can derail the demo",
                    description: "The video uses Remix Icon and SVG copy/download, but a live demo should not get stuck browsing icon libraries.",
                    source: "youtube-captions-v1",
                    stepNumber: 5,
                    fix: "Use any available sparkle/star icon if SVG import is slow, then continue to the shader effects.",
                    createdAt: createdAt
                ),
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888805")!,
                    skillId: skillId,
                    title: "Shader tuning is intentionally fuzzy",
                    description: "The creator experiments with colors, blend modes, scale, brightness, and border colors rather than following exact numeric values.",
                    source: "browser-use-hardening",
                    stepNumber: 6,
                    fix: "Make one visible improvement, verify readability, and move on instead of over-tuning.",
                    createdAt: createdAt
                )
            ],
            criteria: [
                SkillAcceptanceCriterion(
                    id: UUID(uuidString: "99999999-9999-4999-8999-999999999903")!,
                    skillId: skillId,
                    criterion: "Guide mode can take the user from a saved Paper.design YouTube tutorial to a visible Ask AI-style shader card without relying on Browser Use."
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
                    title: "Have a sparkle icon fallback",
                    detail: "The video pulls a sparkle icon from Remix Icon. For the demo, any visible sparkle/star SVG or icon is acceptable if Remix Icon slows things down.",
                    kind: "asset",
                    source: "youtube-captions-v1",
                    stepNumber: 5,
                    isBlocking: false,
                    actionLabel: "Icon ready"
                ),
                PawscriptPrerequisite(
                    id: UUID(uuidString: "77777777-7777-4777-8777-777777777705")!,
                    title: "Use Guide me for the live demo",
                    detail: "Browser Use can be flaky inside Paper's editor. For the deterministic demo, use Spanks as a screen-observing guide after the setup checkpoint.",
                    kind: "safety",
                    source: "browser-use-hardening",
                    stepNumber: 1,
                    isBlocking: false,
                    actionLabel: "Guide mode OK"
                )
            ],
            sourceKind: .youtube,
            sourceURL: "https://www.youtube.com/watch?v=Ny3rvJWT5PM",
            extractedSummary: "The video shows how to recreate a viral Ask AI-style social graphic in Paper.design. This demo version uses deterministic guide steps: create a 520x180 dark rounded card, add a 116x116 left circle, place Liquid Metal inside it, add white Ask AI text and a sparkle icon, apply Neuron Noise with Multiply to the text, add a rounded Pulsing Border, and stop at visual verification.",
            toolsUsed: ["Paper.design", "Liquid Metal shader", "Remix Icon", "SVG import", "Text tool", "Neuron Noise", "Multiply blending", "Pulsing Border"],
            promptSnippets: [
                "After setup, prefer Guide me: observe the current Paper canvas, point at likely controls, and let the human click.",
                "If Paper asks for login, signup, payment, or project selection, ask the user to complete that step manually.",
                "Use the deterministic demo values: card 520x180 radius 44 fill #151515, circle 116x116 fill #2F7DFF, Ask AI white 44px, sparkle/star 40px.",
                "Prefer visible labels and concepts from the video: rectangle, border radius, circle, shaders, Liquid Metal, sparkle SVG, Ask AI, Neuron Noise, Multiply, Pulsing Border.",
                "Make visible design progress quickly: one metal shader, one text shader, one border effect.",
                "Do not chase export during the live demo. End when the Ask AI shader card is visibly complete."
            ],
            customizationQuestion: "What should the Ask AI-style Paper card say, and should Spanks prioritize speed or visual polish?"
        )
    }

    private static var fallbackDate: Date {
        ISO8601DateFormatter().date(from: "2026-04-16T00:00:00Z") ?? Date()
    }
}
