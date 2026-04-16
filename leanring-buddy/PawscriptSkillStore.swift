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
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666601")!,
                skillId: skillId,
                number: 1,
                title: "Open an editable Paper canvas",
                action: "navigate",
                target: "https://paper.design/",
                value: "https://paper.design/",
                description: "Open Paper and get to a signed-in editable canvas. If you see marketing, signup, login, or an empty workspace, finish setup manually, then click I'm done.",
                verification: "An editable Paper canvas is visible.",
                gotchaText: "If Paper opens a landing page, sign in or open a canvas before continuing.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666602")!,
                skillId: skillId,
                number: 2,
                title: "Handle login or canvas handoff",
                action: "conditional",
                target: "Paper editor state",
                value: "Click I'm done only when a canvas is open.",
                description: "Pause here until the user confirms the Paper canvas is ready. Do not try to automate login, account setup, or private workspace selection.",
                verification: "The next visible screen is an editable Paper canvas.",
                gotchaText: "Do not attempt credentials, billing, or account settings.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666603")!,
                skillId: skillId,
                number: 3,
                title: "Draw the dark rounded card",
                action: "configure",
                target: "Rectangle tool, Fill, Radius, Width, Height",
                value: "Card: 520x180, radius 44, fill #151515.",
                description: "Draw one rounded rectangle for the main card. Use the reference values exactly if Paper exposes numeric controls; otherwise match the size visually.",
                verification: "One dark rounded card is visible on the canvas.",
                gotchaText: "If exact fields are hidden, approximate the size visually and continue.",
                estimatedTime: "45s"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666604")!,
                skillId: skillId,
                number: 4,
                title: "Add the left circle",
                action: "configure",
                target: "Ellipse or rounded rectangle tool, Fill, Width, Height",
                value: "Circle: 116x116, fill #2F7DFF, left aligned, vertically centered.",
                description: "Add a circle on the left side of the card. This is the placeholder that will receive the Liquid Metal shader.",
                verification: "A blue circle is visible on the left side of the dark card.",
                gotchaText: "If the circle disappears, check Paper layer order before changing anything else.",
                estimatedTime: "45s"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666605")!,
                skillId: skillId,
                number: 5,
                title: "Add Liquid Metal to the circle",
                action: "configure",
                target: "Shaders panel, Liquid Metal shader, opacity/background control",
                value: "Shader: Liquid Metal. Background opacity: 0 if visible. Keep it inside the circle.",
                description: "Open shaders/effects, choose Liquid Metal, and place it over the left circle. If Liquid Metal is missing, choose the closest metal-looking shader and continue.",
                verification: "The left circle now has a metallic shader texture.",
                gotchaText: "Choose the closest metal shader if the exact name is unavailable.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666606")!,
                skillId: skillId,
                number: 6,
                title: "Add the Ask AI text",
                action: "type",
                target: "Text tool",
                value: "Text: Ask AI, color #FFFFFF, size 44px, vertically centered.",
                description: "Add the exact text Ask AI in white. Place it to the right of the circle and center it vertically inside the card.",
                verification: "The card has readable white Ask AI text.",
                gotchaText: "Keep the text plain if font controls are hard to find.",
                estimatedTime: "45s"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666607")!,
                skillId: skillId,
                number: 7,
                title: "Add a sparkle icon",
                action: "configure",
                target: "Sparkle/star icon or simple drawn star",
                value: "Icon: white sparkle/star, about 40px, immediately left of Ask AI.",
                description: "Add any white sparkle or star icon to the left of the Ask AI text. If importing SVG is slow, draw a simple star or skip the icon after saying so.",
                verification: "A sparkle/star icon or placeholder appears beside the text.",
                gotchaText: "Do not spend demo time hunting icon libraries.",
                estimatedTime: "45s"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666608")!,
                skillId: skillId,
                number: 8,
                title: "Add Neuron Noise to the text",
                action: "configure",
                target: "Neuron Noise shader, blending mode, color controls",
                value: "Neuron Noise over text. Blend: Multiply. Scale: 2. Brightness: 70%. Colors: blue + gray.",
                description: "Apply Neuron Noise over the text area only. Set Multiply, scale, brightness, and colors when visible. If controls are hidden, make one visible noise/text change and continue.",
                verification: "The Ask AI text has a subtle blue-gray shader treatment and stays readable.",
                gotchaText: "Do not over-tune. One visible text effect is enough.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666609")!,
                skillId: skillId,
                number: 9,
                title: "Add the Pulsing Border",
                action: "configure",
                target: "Pulsing Border shader, roundness, opacity, color controls",
                value: "Border: Pulsing Border. Roundness: 100%. Background opacity: 0. Colors: blue/green.",
                description: "Add Pulsing Border around the outside of the card. Max the roundness, hide the background if possible, resize it to the card, and switch harsh red/orange colors to blue/green if controls are visible.",
                verification: "A rounded pulsing/glowing border frames the card without covering the content.",
                gotchaText: "If color controls are hidden, keep the default border and advance.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666610")!,
                skillId: skillId,
                number: 10,
                title: "Verify the final graphic",
                action: "verify",
                target: "Final Paper canvas",
                value: "Done when: dark card + metal circle + Ask AI text + sparkle + text shader + pulsing border.",
                description: "Stop when the card has the six visible pieces from the reference. Do not chase export during the live demo.",
                verification: "The user can see the finished Ask AI-style shader card on the Paper canvas.",
                gotchaText: "The demo win is guided execution, not export polish.",
                estimatedTime: "30s"
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
              - title: Draw the dark rounded card
              - title: Add the left circle
              - title: Add Liquid Metal to the circle
              - title: Add the Ask AI text
              - title: Add a sparkle icon
              - title: Add Neuron Noise to the text
              - title: Add the Pulsing Border
              - title: Verify the final graphic
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
                value: """
                1. Open https://paper.design/
                2. Sign in if Paper asks
                3. Create or open any editable canvas
                Good enough: a blank editable Paper canvas is visible
                """,
                description: "Open Paper and get to an editable canvas before drawing anything.",
                verification: "A Paper canvas is visible and ready for shapes. Marketing pages, signup pages, or static galleries are not good enough.",
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
                value: """
                1. Complete login manually if needed
                2. Pick any safe demo file or blank canvas
                3. Press I'm done - continue
                Good enough: the canvas is editable and Spanks can continue from this screen
                """,
                description: "Use this as the human checkpoint for account, file, or project setup.",
                verification: "The user has confirmed the editable Paper canvas is ready.",
                gotchaText: "Do not attempt to create accounts, enter private credentials, or change billing settings.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666603")!,
                skillId: skillId,
                number: 3,
                title: "Draw the dark rounded card",
                action: "configure",
                target: "Rectangle tool, Fill, Radius, Width, Height",
                value: """
                1. Select Rectangle
                2. Draw a wide horizontal card
                3. Set W 520 / H 180 if fields are visible
                4. Set radius 44 if visible
                5. Set fill #151515
                Good enough: a dark rounded card is on the canvas
                """,
                description: "Create the base shape for the Ask AI social graphic.",
                verification: "A single dark rounded rectangle is visible. Exact dimensions are optional if it visually reads as a wide card.",
                gotchaText: "Paper's layers feel reversed compared with Figma: lower items in the layers panel can appear visually above. If the circle disappears, check layer order.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666604")!,
                skillId: skillId,
                number: 4,
                title: "Add the left circle",
                action: "configure",
                target: "Ellipse tool, Fill, Width, Height, Align",
                value: """
                1. Select Ellipse or Circle
                2. Draw a circle inside the left side of the card
                3. Set W 116 / H 116 if fields are visible
                4. Set fill #2F7DFF
                5. Center it vertically inside the card
                Good enough: a blue circle sits inside the left side of the card
                """,
                description: "Add the circle that will receive the metal shader.",
                verification: "The blue circle is visible on top of the card and roughly centered vertically.",
                gotchaText: "If the circle disappears, check layer order before redrawing it.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666605")!,
                skillId: skillId,
                number: 5,
                title: "Add Liquid Metal to the circle",
                action: "configure",
                target: "Shaders panel, Liquid Metal shader, opacity/background control",
                value: """
                1. Open Shaders or Effects
                2. Choose Liquid Metal
                3. Place it over the blue circle
                4. Set background opacity to 0 if visible
                5. Resize it to fit inside the circle
                Good enough: the circle looks metallic
                """,
                description: "Apply one obvious metal shader treatment to the circle.",
                verification: "The left circle area now has a metallic shader texture while staying inside the card.",
                gotchaText: "If Liquid Metal is not visible by exact name, choose the most obvious metal-looking shader and keep moving.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666606")!,
                skillId: skillId,
                number: 6,
                title: "Add the Ask AI text",
                action: "configure",
                target: "Text tool, color, size, alignment",
                value: """
                1. Select Text
                2. Type Ask AI
                3. Set color #FFFFFF
                4. Set size 44 if visible
                5. Place it to the right of the circle
                Good enough: white Ask AI text is readable inside the card
                """,
                description: "Add the main label from the tutorial graphic.",
                verification: "The card clearly reads Ask AI in white text.",
                gotchaText: "If exact font controls are hard to find, prioritize readable white text over exact typography.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666607")!,
                skillId: skillId,
                number: 7,
                title: "Add a sparkle icon",
                action: "configure",
                target: "Icon, star, sparkle, or simple placeholder",
                value: """
                1. Add any sparkle/star icon
                2. Set color #FFFFFF
                3. Set size about 40
                4. Place it left of Ask AI
                5. Skip if icon sourcing is slow
                Good enough: a sparkle, star, or simple placeholder is visible
                """,
                description: "Add the small visual cue next to the Ask AI text.",
                verification: "A sparkle/star icon or acceptable placeholder appears between the circle and text.",
                gotchaText: "If importing SVG is slow, skip the icon import and use any visible sparkle/star icon or simple placeholder.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666608")!,
                skillId: skillId,
                number: 8,
                title: "Add Neuron Noise to the text",
                action: "configure",
                target: "Neuron Noise shader, blending mode, color controls",
                value: """
                1. Add Neuron Noise
                2. Place it over the Ask AI text only
                3. Set blend to Multiply if visible
                4. Set scale about 2 if visible
                5. Set brightness about 70% if visible
                Good enough: the text has subtle texture but stays readable
                """,
                description: "Apply one visible texture treatment to the text without over-tuning.",
                verification: "The Ask AI text has a subtle blue-gray shader/noise treatment while remaining readable.",
                gotchaText: "Do not over-tune. Apply one visible Neuron Noise treatment and advance.",
                estimatedTime: "2min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666609")!,
                skillId: skillId,
                number: 9,
                title: "Add the Pulsing Border",
                action: "configure",
                target: "Pulsing Border shader, roundness, opacity, color controls",
                value: """
                1. Add Pulsing Border
                2. Place it around the card
                3. Set roundness to 100% if visible
                4. Set background opacity to 0 if visible
                5. Use blue/green colors if controls are visible
                Good enough: a glowing rounded border frames the card
                """,
                description: "Frame the card with the final shader effect from the tutorial.",
                verification: "A pulsing or glowing rounded border frames the card without covering the icon or Ask AI text.",
                gotchaText: "If color controls are not visible, keep the default border and advance. The key visible payoff is the border framing the card.",
                estimatedTime: "1min"
            ),
            SkillStep(
                id: UUID(uuidString: "66666666-6666-4666-8666-666666666610")!,
                skillId: skillId,
                number: 10,
                title: "Verify the final graphic",
                action: "verify",
                target: "Final Paper canvas",
                value: """
                Check: dark rounded card
                Check: metal circle
                Check: Ask AI text
                Check: sparkle icon or placeholder
                Check: text texture
                Check: pulsing border
                Good enough: a visible Ask AI shader card exists
                """,
                description: "Compare the result to the tutorial target and stop at visible completion.",
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
                    stepNumber: 7,
                    fix: "Use any available sparkle/star icon if SVG import is slow, then continue to the shader effects.",
                    createdAt: createdAt
                ),
                SkillGotcha(
                    id: UUID(uuidString: "88888888-8888-4888-8888-888888888805")!,
                    skillId: skillId,
                    title: "Shader tuning is intentionally fuzzy",
                    description: "The creator experiments with colors, blend modes, scale, brightness, and border colors rather than following exact numeric values.",
                    source: "browser-use-hardening",
                    stepNumber: 9,
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
                    stepNumber: 7,
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
            extractedSummary: "The video shows how to recreate a viral Ask AI-style social graphic in Paper.design. This demo version breaks each step into concrete substeps with a Good enough checkpoint: create a 520x180 dark rounded card, add a 116x116 left circle, place Liquid Metal inside it, add white Ask AI text, add a sparkle icon, apply Neuron Noise with Multiply to the text, add a rounded Pulsing Border, and stop at visual verification.",
            toolsUsed: ["Paper.design", "Liquid Metal shader", "Remix Icon", "SVG import", "Text tool", "Neuron Noise", "Multiply blending", "Pulsing Border"],
            promptSnippets: [
                "After setup, prefer Guide me: observe the current Paper canvas, point at likely controls, and let the human click.",
                "If Paper asks for login, signup, payment, or project selection, ask the user to complete that step manually.",
                "Show the user the substeps and Good enough checkpoint before moving to the next step.",
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
