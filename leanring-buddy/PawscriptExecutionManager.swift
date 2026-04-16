//
//  PawscriptExecutionManager.swift
//  leanring-buddy
//
//  Main state machine for Pawscript's tutorial-source-to-guidance flow.
//

import AppKit
import Foundation

@MainActor
final class PawscriptExecutionManager: ObservableObject {
    @Published var selectedSourceKind: PawscriptSourceKind = .youtube
    @Published var sourceURL: String = "https://www.youtube.com/watch?v=Q_bd7BFh0XY"
    @Published var customizationGoal: String = "Turn this saved tutorial into an active browser workflow."
    @Published private(set) var activePackage: PawscriptSkillPackage?
    @Published private(set) var generatedPrompt: String = ""
    @Published private(set) var fallbackNotice: String?
    @Published private(set) var runState: PawscriptRunState = .idle
    @Published private(set) var currentStepIndex: Int = 0
    @Published private(set) var executionEvents: [PawscriptExecutionEvent] = []
    @Published private(set) var lastWorkspacePath: String?
    @Published private(set) var lastScreenMatch: PawscriptScreenMatch?
    @Published private(set) var activeMode: PawscriptExecutionMode?
    @Published private(set) var prerequisitesConfirmed: Bool = false
    @Published private(set) var latestRunLogURL: URL?
    @Published private(set) var browserUseHandoffActive: Bool = false
    @Published private(set) var browserUseHandoffMessage: String?

    private let skillStore: PawscriptSkillStore
    private let sourceExtractor: PawscriptSourceExtractor
    private let promptBuilder: PawscriptPromptBuilder
    private let screenMatcher: PawscriptScreenMatcher
    private let browserUseExecutor: PawscriptBrowserUseExecutor
    private let contextCapture: PawscriptContextCapture
    private let runLogger: PawscriptRunLogger
    private let urlResolver: PawscriptURLResolver
    private var currentRunTask: Task<Void, Never>?
    private var stuckSince: Date?
    private var lastCapturedStuckKey: String?
    private var pendingModeAfterPrerequisites: PawscriptExecutionMode?
    private var browserUseStopRequested = false

    var statusNarrationHandler: ((String) -> Void)?
    var pointAtCurrentStepHandler: ((SkillStep) -> Void)?
    var pointAtScreenMatchHandler: ((SkillStep, PawscriptScreenMatch) -> Void)?

    init(
        skillStore: PawscriptSkillStore = PawscriptSkillStore(),
        promptBuilder: PawscriptPromptBuilder = PawscriptPromptBuilder(),
        screenMatcher: PawscriptScreenMatcher = PawscriptScreenMatcher(),
        browserUseExecutor: PawscriptBrowserUseExecutor = PawscriptBrowserUseExecutor(),
        contextCapture: PawscriptContextCapture = PawscriptContextCapture(),
        runLogger: PawscriptRunLogger = PawscriptRunLogger(),
        urlResolver: PawscriptURLResolver = PawscriptURLResolver()
    ) {
        self.skillStore = skillStore
        self.sourceExtractor = PawscriptSourceExtractor(skillStore: skillStore)
        self.promptBuilder = promptBuilder
        self.screenMatcher = screenMatcher
        self.browserUseExecutor = browserUseExecutor
        self.contextCapture = contextCapture
        self.runLogger = runLogger
        self.urlResolver = urlResolver
        loadDefaultDocFallbackIfPossible()
    }

    var currentStep: SkillStep? {
        guard let activePackage,
              activePackage.steps.indices.contains(currentStepIndex) else {
            return nil
        }
        return activePackage.steps.sorted { $0.number < $1.number }[currentStepIndex]
    }

    var progressLabel: String {
        guard let activePackage else { return "No skill loaded" }
        return "Step \(min(currentStepIndex + 1, activePackage.steps.count)) of \(activePackage.steps.count)"
    }

    var canRun: Bool {
        activePackage != nil && activeMode == nil && runState != .running && runState != .extracting && runState != .paused
    }

    var canPauseGuide: Bool {
        activeMode == .doTogether && runState == .running
    }

    var canResumeGuide: Bool {
        activeMode == .doTogether && runState == .paused
    }

    var canStopGuide: Bool {
        activeMode == .doTogether && (runState == .running || runState == .paused)
    }

    var canContinueBrowserUse: Bool {
        activeMode == .watchMe && browserUseHandoffActive
    }

    var canStopBrowserUse: Bool {
        activeMode == .watchMe && (runState == .running || browserUseHandoffActive)
    }

    var needsPrerequisiteConfirmation: Bool {
        guard let activePackage else { return false }
        return !prerequisitesConfirmed && !activePackage.blockingPrerequisites.isEmpty
    }

    func openLatestRunLog() {
        guard let latestRunLogURL else { return }
        NSWorkspace.shared.open(latestRunLogURL)
    }

    func loadSelectedSource() {
        currentRunTask?.cancel()
        activeMode = nil
        runState = .extracting
        fallbackNotice = nil
        executionEvents = []
        currentStepIndex = 0
        generatedPrompt = ""
        lastScreenMatch = nil
        prerequisitesConfirmed = false
        stuckSince = nil
        lastCapturedStuckKey = nil
        pendingModeAfterPrerequisites = nil
        browserUseHandoffActive = false
        browserUseHandoffMessage = nil
        browserUseStopRequested = false
        latestRunLogURL = runLogger.startRun(
            mode: "extract",
            package: nil,
            sourceURL: sourceURL,
            currentStep: nil
        )
        announce("Got it. Turning that saved tutorial into an active Pawscript session.")

        Task {
            do {
                let result = try await sourceExtractor.extract(kind: selectedSourceKind, sourceURL: sourceURL)
                var package = urlResolver.normalizedPackage(result.package)
                package.sourceKind = selectedSourceKind
                if !sourceURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    package.sourceURL = sourceURL
                }

                activePackage = package
                fallbackNotice = result.fallbackNotice
                generatedPrompt = promptBuilder.buildPrompt(
                    package: package,
                    userGoal: customizationGoal,
                    mode: .watchMe
                )
                if package.blockingPrerequisites.isEmpty {
                    runState = .ready
                } else {
                    runState = .waitingForHuman("Prerequisites need a quick human checkpoint before automation.")
                }
                addEvent(title: "Skill loaded", detail: "\(package.steps.count) steps found from \(package.sourceKind.label).")
                addPrerequisiteEventIfNeeded(package)
                try? skillStore.savePackage(package)
                announceLoadedSkill(package)
                runLogger.finishRun(
                    state: "completed",
                    package: package,
                    currentStep: currentStep
                )
            } catch {
                runState = .failed(error.localizedDescription)
                addEvent(title: "Extraction failed", detail: error.localizedDescription)
                announce("I could not load that tutorial. Try the OpenAI doc fallback.")
                runLogger.finishRun(
                    state: "failed",
                    package: activePackage,
                    currentStep: currentStep,
                    errorSummary: error.localizedDescription
                )
            }
        }
    }

    private func loadDefaultDocFallbackIfPossible() {
        do {
            let package = urlResolver.normalizedPackage(try skillStore.loadBundledSkill(named: "openai-delightful-frontends"))
            activePackage = package
            fallbackNotice = "OpenAI doc fallback preloaded for the demo."
            generatedPrompt = promptBuilder.buildPrompt(
                package: package,
                userGoal: customizationGoal,
                mode: .watchMe
            )
            runState = .ready
            addEvent(title: "Fallback ready", detail: "\(package.steps.count) OpenAI frontend guide steps preloaded.")
            addPrerequisiteEventIfNeeded(package)
        } catch {
            runState = .failed(error.localizedDescription)
            addEvent(title: "Fallback missing", detail: error.localizedDescription)
        }
    }

    func refreshGeneratedPrompt(for mode: PawscriptExecutionMode) {
        guard let activePackage else { return }
        generatedPrompt = promptBuilder.buildPrompt(
            package: activePackage,
            userGoal: customizationGoal,
            mode: mode
        )
    }

    func runWatchMe() {
        guard var activePackage else { return }
        activePackage = urlResolver.normalizedPackage(activePackage)
        self.activePackage = activePackage
        if needsPrerequisiteConfirmation {
            prerequisitesConfirmed = true
            pendingModeAfterPrerequisites = nil
            addEvent(title: "Agent will verify setup", detail: "Pawscript Chrome will open the page and pause if login or setup is needed.")
        }
        activeMode = .watchMe
        runState = .running
        browserUseHandoffActive = false
        browserUseHandoffMessage = nil
        browserUseStopRequested = false
        latestRunLogURL = runLogger.startRun(
            mode: PawscriptExecutionMode.watchMe.rawValue,
            package: activePackage,
            sourceURL: sourceURL,
            currentStep: currentStep
        )
        addEvent(title: "Pawscript Chrome starting", detail: "Opening one dedicated Chrome window for this skill.")
        announce("Watch Spanks do it. I am opening Pawscript Chrome. If login appears, I will pause and let you take over in that same window.")
        dismissMenuPanel()

        currentRunTask?.cancel()
        currentRunTask = Task {
            do {
                let preflightIssues = await urlResolver.preflightNavigableSteps(in: activePackage)
                if let issue = preflightIssues.first {
                    await handleBadURLPreflight(issue, package: activePackage)
                    return
                }

                let result = try await browserUseExecutor.run(
                    package: activePackage,
                    userGoal: customizationGoal,
                    runLogger: runLogger,
                    onEvent: { [weak self] event in
                        Task { @MainActor [weak self] in
                            self?.handleBrowserUseEvent(event)
                        }
                    }
                )
                var updatedPackage = activePackage
                updatedPackage.skill.agentCompletions += 1
                updatedPackage.skill.updatedAt = Date()
                self.activePackage = updatedPackage
                try? skillStore.savePackage(updatedPackage)
                runState = .completed
                activeMode = nil
                browserUseHandoffActive = false
                browserUseHandoffMessage = nil
                browserUseStopRequested = false
                stuckSince = nil
                currentStepIndex = max(0, updatedPackage.steps.count - 1)
                addEvent(title: "Browser Use complete", detail: result.output.isEmpty ? "The browser workflow finished." : Self.shortText(result.output))
                announce("All set. Spanks completed the browser workflow and I counted one agent completion.")
                runLogger.finishRun(
                    state: "completed",
                    package: updatedPackage,
                    currentStep: currentStep,
                    browserUseExitCode: 0
                )
            } catch {
                if browserUseStopRequested {
                    runState = .ready
                    activeMode = nil
                    browserUseHandoffActive = false
                    browserUseHandoffMessage = nil
                    browserUseStopRequested = false
                    addEvent(title: "Browser Use stopped", detail: "No agent completion was recorded.")
                    announce("Stopped. Spanks will leave the browser where it is.")
                    runLogger.finishRun(
                        state: "stopped",
                        package: activePackage,
                        currentStep: currentStep
                    )
                    return
                }

                var updatedPackage = activePackage
                let browserUseExitCode = (error as? PawscriptBrowserUseExecutorError)?.exitCode
                let capture = await captureStuckContext(
                    package: updatedPackage,
                    step: currentStep,
                    reason: "Browser Use execution failed",
                    eventMessage: error.localizedDescription,
                    source: "agent-execution-browser-use-v1",
                    force: true
                )
                let gotcha = SkillGotcha(
                    skillId: updatedPackage.skill.id,
                    title: "Browser Use execution needed help",
                    description: Self.describeStuckContext(
                        message: error.localizedDescription,
                        capture: capture
                    ),
                    source: "agent-execution-browser-use-v1",
                    stepNumber: currentStep?.number,
                    fix: "Check Browser Use setup, visible browser permissions, and whether the workflow requires credentials."
                )
                updatedPackage.appendUniqueGotcha(gotcha)
                updatedPackage.skill.updatedAt = Date()
                self.activePackage = updatedPackage
                try? skillStore.savePackage(updatedPackage)
                runState = .waitingForHuman(Self.shortText(error.localizedDescription))
                activeMode = nil
                browserUseHandoffActive = false
                browserUseHandoffMessage = nil
                addEvent(title: "Browser Use needs help", detail: Self.shortText(error.localizedDescription))
                announce("Spanks found a missing prerequisite and needs you to jump in. I saved it as a gotcha.")
                runLogger.finishRun(
                    state: "waitingForHuman",
                    package: updatedPackage,
                    currentStep: currentStep,
                    browserUseExitCode: browserUseExitCode.map(Int.init),
                    errorSummary: Self.shortText(error.localizedDescription, limit: 800)
                )
            }
        }
    }

    func continueBrowserUseAfterHumanHelp() {
        guard canContinueBrowserUse else { return }
        let note = "The user resolved the visible browser blocker and asked Spanks to continue."
        browserUseHandoffActive = false
        browserUseHandoffMessage = nil
        runState = .running
        addEvent(title: "Human checkpoint resolved", detail: "Continuing Browser Use from the same visible browser.")
        runLogger.updateRun(state: "running", package: activePackage, currentStep: currentStep)
        browserUseExecutor.continueAfterHumanHelp(note: note)
        dismissMenuPanel()
        announce("Perfect. I will continue from this browser, not start over.")
    }

    func stopBrowserUse() {
        guard canStopBrowserUse else { return }
        browserUseStopRequested = true
        browserUseHandoffActive = false
        browserUseHandoffMessage = nil
        addEvent(title: "Stopping Browser Use", detail: "User stopped the live browser automation.")
        browserUseExecutor.stopRunningProcess()
        announce("Stopping Browser Use. I will leave the browser open if it is still there.")
    }

    func confirmPrerequisites() {
        prerequisitesConfirmed = true
        let pendingMode = pendingModeAfterPrerequisites
        pendingModeAfterPrerequisites = nil
        browserUseHandoffActive = false
        browserUseHandoffMessage = nil
        runState = activePackage == nil ? .idle : .ready
        addEvent(title: "Prerequisites confirmed", detail: "Spanks can now guide or automate the skill.")
        announce("Perfect. I will continue now that the setup is ready.")
        switch pendingMode {
        case .watchMe:
            runWatchMe()
        case .doTogether:
            startDoTogether()
        case .copyIntoCodex:
            copyPromptIntoCodex()
        case nil:
            break
        }
    }

    func helpWithPrerequisites() {
        guard let activePackage else { return }
        dismissMenuPanel()
        Task { @MainActor in
            await openAndPointAtPrerequisite(for: activePackage)
        }
    }

    func copyPromptIntoCodex() {
        guard activePackage != nil else { return }
        refreshGeneratedPrompt(for: .copyIntoCodex)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedPrompt, forType: .string)
        runState = .ready
        addEvent(title: "Prompt copied", detail: "Paste it into Codex to run the skill manually.")
        announce("I copied the Codex prompt. Paste it into Codex and I'll follow along.")
        if let currentStep {
            pointAtCurrentStepHandler?(currentStep)
        }
    }

    func startDoTogether() {
        guard var activePackage else { return }
        activePackage = urlResolver.normalizedPackage(activePackage)
        self.activePackage = activePackage
        guard !needsPrerequisiteConfirmation else {
            pendingModeAfterPrerequisites = .doTogether
            pauseForPrerequisites(activePackage)
            return
        }
        refreshGeneratedPrompt(for: .doTogether)
        currentStepIndex = 0
        activeMode = .doTogether
        runState = .running
        stuckSince = nil
        lastCapturedStuckKey = nil
        latestRunLogURL = runLogger.startRun(
            mode: PawscriptExecutionMode.doTogether.rawValue,
            package: activePackage,
            sourceURL: sourceURL,
            currentStep: currentStep
        )
        addEvent(title: "Guide mode started", detail: "Watching the screen and pointing at the current tutorial step.")
        dismissMenuPanel()
        announceCurrentStep()
        startScreenMatchingLoop()
    }

    func pauseGuide() {
        guard canPauseGuide else { return }
        currentRunTask?.cancel()
        runState = .paused
        addEvent(title: "Guide paused", detail: "Screen matching is paused. Reopen Pawscript to resume or stop.")
        runLogger.updateRun(state: "paused", package: activePackage, currentStep: currentStep)
        announce("Guide paused. I will wait here.")
    }

    func resumeGuide() {
        guard canResumeGuide else { return }
        runState = .running
        addEvent(title: "Guide resumed", detail: "Watching the screen again.")
        runLogger.updateRun(state: "running", package: activePackage, currentStep: currentStep)
        dismissMenuPanel()
        announce("Guide resumed.")
        startScreenMatchingLoop()
    }

    func stopGuide() {
        guard canStopGuide else { return }
        currentRunTask?.cancel()
        activeMode = nil
        runState = activePackage == nil ? .idle : .ready
        stuckSince = nil
        lastCapturedStuckKey = nil
        addEvent(title: "Guide stopped", detail: "No completion was recorded.")
        runLogger.finishRun(state: "stopped", package: activePackage, currentStep: currentStep)
        announce("Guide stopped.")
    }

    func advanceHumanStep() {
        guard var activePackage else { return }
        let sortedSteps = activePackage.steps.sorted { $0.number < $1.number }
        if currentStepIndex + 1 < sortedSteps.count {
            currentStepIndex += 1
            stuckSince = nil
            lastCapturedStuckKey = nil
            runLogger.updateRun(state: "running", package: activePackage, currentStep: currentStep)
            announceCurrentStep()
        } else {
            activePackage.skill.humanCompletions += 1
            activePackage.skill.updatedAt = Date()
            self.activePackage = activePackage
            try? skillStore.savePackage(activePackage)
            runState = .completed
            activeMode = nil
            stuckSince = nil
            currentRunTask?.cancel()
            addEvent(title: "Human run complete", detail: "humanCompletions incremented.")
            runLogger.finishRun(state: "completed", package: activePackage, currentStep: currentStep)
            announce("Nice. You completed the skill, and I updated human completions.")
        }
    }

    func markCurrentStepStuck(source: String = "button") {
        guard var activePackage,
              let currentStep else { return }
        addEvent(title: "Manual stuck", detail: "User marked \(currentStep.title) as stuck via \(source).")
        Task { @MainActor in
            let capture = await captureStuckContext(
                package: activePackage,
                step: currentStep,
                reason: "User manually marked stuck via \(source)",
                eventMessage: currentStep.gotchaText ?? "The user needed extra help on this step.",
                source: "human-observation",
                force: true
            )
            let gotcha = SkillGotcha(
                skillId: activePackage.skill.id,
                title: "Human got stuck on \(currentStep.title)",
                description: Self.describeStuckContext(
                    message: currentStep.gotchaText ?? "The user needed extra help on this step.",
                    capture: capture
                ),
                source: "human-observation",
                stepNumber: currentStep.number,
                fix: currentStep.verification
            )
            activePackage.appendUniqueGotcha(gotcha)
            activePackage.skill.updatedAt = Date()
            self.activePackage = activePackage
            try? skillStore.savePackage(activePackage)
            addEvent(title: "Gotcha saved", detail: gotcha.description)
            runLogger.updateRun(state: "manualStuck", package: activePackage, currentStep: currentStep)
            announce("Got it. I saved this as a gotcha with the current screen.")
        }
    }

    private func announceCurrentStep() {
        guard let currentStep else { return }
        addEvent(title: currentStep.title, detail: currentStep.description)
        pointAtCurrentStepHandler?(currentStep)
        openTargetIfNavigable(currentStep)
        announce("Step \(currentStep.number): \(Self.shortText(currentStep.description, limit: 180))")
    }

    private func addPrerequisiteEventIfNeeded(_ package: PawscriptSkillPackage) {
        let blocking = package.blockingPrerequisites
        guard !blocking.isEmpty else { return }
        let detail = blocking.map(\.title).joined(separator: ", ")
        addEvent(title: "Prerequisites found", detail: detail)
    }

    private func announceLoadedSkill(_ package: PawscriptSkillPackage) {
        let countText = "\(package.steps.count) steps found."
        let blocking = package.blockingPrerequisites
        if blocking.isEmpty {
            announce("\(countText) I can guide you through it or watch Spanks do the browser steps.")
        } else {
            let first = blocking[0]
            announce("\(countText) I found a hidden prerequisite: \(first.title). \(first.detail)")
        }
    }

    private func pauseForPrerequisites(_ package: PawscriptSkillPackage) {
        let blocking = package.blockingPrerequisites
        let first = blocking[0]
        runState = .waitingForHuman(first.detail)
        activeMode = nil
        addEvent(title: "Human checkpoint", detail: "\(first.title): \(first.detail)")
        announce("Tiny setup checkpoint. I will open the page and point where you probably need to sign in or prepare the session.")
        Task { @MainActor in
            await openAndPointAtPrerequisite(for: package)
        }
    }

    private func startScreenMatchingLoop() {
        currentRunTask?.cancel()
        currentRunTask = Task {
            while !Task.isCancelled {
                guard runState == .running,
                      activeMode == .doTogether,
                      let currentStep else { return }

                do {
                    let match = try await screenMatcher.match(step: currentStep)
                    lastScreenMatch = match
                    if match.hasCoordinate && match.confidence >= 0.25 {
                        pointAtScreenMatchHandler?(currentStep, match)
                    }
                } catch {
                    addEvent(title: "Screen match skipped", detail: error.localizedDescription)
                }

                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    private func openTargetIfNavigable(_ step: SkillStep) {
        guard step.action == "navigate" else { return }
        let rawURL = step.value ?? step.target ?? ""
        guard let url = urlResolver.normalizedURL(from: rawURL, context: stepContext(step)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openAndPointAtPrerequisite(for package: PawscriptSkillPackage) async {
        guard let prerequisite = package.blockingPrerequisites.first ?? package.effectivePrerequisites.first else {
            return
        }

        if let url = prerequisiteURL(for: package),
           NSWorkspace.shared.open(url) {
            addEvent(title: "Opened setup page", detail: url.absoluteString)
        }

        dismissMenuPanel()
        announce("I opened the app page. I am looking for sign in, account, workspace, or setup controls now.")
        try? await Task.sleep(nanoseconds: 1_700_000_000)

        let step = SkillStep(
            skillId: package.skill.id,
            number: prerequisite.stepNumber ?? 0,
            title: prerequisite.title,
            action: "click",
            target: "sign in, log in, account, workspace, dashboard, project, editor, upload, or setup control",
            value: nil,
            description: prerequisite.detail,
            verification: "The user has completed the setup checkpoint and is ready to continue.",
            gotchaText: prerequisite.detail
        )

        do {
            let match = try await screenMatcher.match(step: step)
            lastScreenMatch = match
            if match.hasCoordinate && match.confidence >= 0.2 {
                pointAtScreenMatchHandler?(step, match)
                addEvent(title: "Pointing at setup", detail: match.hint)
                announce(match.hint.isEmpty ? "I found the likely setup spot. Sign in or prepare the session, then tell me you are done." : Self.shortText(match.hint))
            } else {
                pointAtCurrentStepHandler?(step)
                addEvent(title: "Setup target unclear", detail: match.hint)
                announce("I opened the page, but I am not fully sure where the setup target is. Sign in or prepare the session, then tell me you are done.")
            }
        } catch {
            pointAtCurrentStepHandler?(step)
            addEvent(title: "Setup pointing skipped", detail: error.localizedDescription)
            announce("I opened the page. Sign in or prepare the session, then tell me you are done and I will continue.")
        }
    }

    private func prerequisiteURL(for package: PawscriptSkillPackage) -> URL? {
        let firstStepURL = package.steps
            .sorted { $0.number < $1.number }
            .compactMap { step -> URL? in
                guard step.action == "navigate" else { return nil }
                let rawURL = step.value ?? step.target ?? ""
                return urlResolver.normalizedURL(from: rawURL, context: stepContext(step))
            }
            .first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }

        if let firstStepURL {
            return firstStepURL
        }

        guard let sourceURL = URL(string: package.sourceURL),
              ["http", "https"].contains(sourceURL.scheme?.lowercased() ?? "") else {
            return nil
        }
        return sourceURL
    }

    private func handleBadURLPreflight(
        _ issue: PawscriptURLPreflightIssue,
        package: PawscriptSkillPackage
    ) async {
        var updatedPackage = package
        let message = "\(issue.url) could not be used before automation. \(issue.reason)"
        let gotcha = SkillGotcha(
            skillId: updatedPackage.skill.id,
            title: "Stale or unreachable tutorial URL",
            description: message,
            source: "agent-execution-browser-use-v1",
            stepNumber: issue.stepNumber,
            fix: "Open the correct page manually or update the extracted navigate URL before running Browser Use."
        )
        updatedPackage.appendUniqueGotcha(gotcha)
        updatedPackage.skill.updatedAt = Date()
        activePackage = updatedPackage
        try? skillStore.savePackage(updatedPackage)
        runState = .waitingForHuman(Self.shortText(message))
        activeMode = nil
        addEvent(title: "Bad URL before agent run", detail: message)
        runLogger.finishRun(
            state: "waitingForHuman",
            package: updatedPackage,
            currentStep: currentStep,
            errorSummary: message
        )
        announce("That tutorial URL looks stale, not signed out. I saved it as a gotcha and need the right page before Browser Use continues.")
    }

    private func handleBrowserUseEvent(_ event: PawscriptBrowserUseEvent) {
        addEvent(title: browserEventTitle(event.type), detail: event.message)
        if event.type == "needs_human" {
            Task { @MainActor [weak self] in
                await self?.handleBrowserUseHumanHandoff(event)
            }
        } else if event.type == "resumed" {
            browserUseHandoffActive = false
            browserUseHandoffMessage = nil
            runState = .running
            announce("Spanks is back in the driver seat.")
        } else if event.type == "stopped" {
            browserUseStopRequested = true
        } else if event.type == "start" || event.type == "browser_launching" || event.type == "browser_ready" || event.type == "running" || event.type == "complete" {
            announce(Self.shortText(event.message))
        }
    }

    private func browserEventTitle(_ type: String) -> String {
        switch type {
        case "start": return "Browser starting"
        case "browser_launching": return "Opening Pawscript Chrome"
        case "browser_ready": return "Pawscript Chrome ready"
        case "running": return "Spanks acting"
        case "complete": return "Agent finished"
        case "error": return "Agent error"
        case "needs_human": return "Needs human"
        case "profile": return "Browser profile"
        case "resumed": return "Agent resumed"
        case "stopped": return "Agent stopped"
        default: return "Browser Use"
        }
    }

    private func announce(_ text: String) {
        statusNarrationHandler?(text)
    }

    private func dismissMenuPanel() {
        NotificationCenter.default.post(name: Notification.Name("clickyDismissPanel"), object: nil)
    }

    private func addEvent(title: String, detail: String) {
        let event = PawscriptExecutionEvent(title: title, detail: Self.shortText(detail, limit: 260))
        executionEvents.insert(event, at: 0)
        if executionEvents.count > 6 {
            executionEvents.removeLast(executionEvents.count - 6)
        }
        runLogger.appendEvent(event)
    }

    private func handleStuckScreenMatch(_ match: PawscriptScreenMatch, step: SkillStep) async {
        let now = Date()
        if stuckSince == nil {
            stuckSince = now
            addEvent(title: "Spanks is thinking", detail: match.hint)
            announce("I might be stuck here. Give me a moment to look around before I interrupt you.")
            _ = await captureStuckContext(
                package: activePackage,
                step: step,
                reason: "Screen matcher reported stuck",
                eventMessage: match.hint,
                source: "human-observation",
                force: false
            )
            return
        }

        let stuckDuration = now.timeIntervalSince(stuckSince ?? now)
        guard stuckDuration >= 30 else {
            addEvent(title: "Still investigating", detail: match.hint)
            return
        }

        let capture = await captureStuckContext(
            package: activePackage,
            step: step,
            reason: "Stuck for more than 30 seconds",
            eventMessage: match.hint,
            source: "human-observation",
            force: true
        )
        let package = activePackage
        if var package {
            let gotcha = SkillGotcha(
                skillId: package.skill.id,
                title: "Human help needed on \(step.title)",
                description: Self.describeStuckContext(message: match.hint, capture: capture),
                source: "human-observation",
                stepNumber: step.number,
                fix: "Ask the user to complete the visible blocker, then continue the skill."
            )
            package.appendUniqueGotcha(gotcha)
            package.skill.updatedAt = Date()
            activePackage = package
            try? skillStore.savePackage(package)
        }
        runState = .waitingForHuman(Self.shortText(match.hint))
        addEvent(title: "Needs human after 30s", detail: match.hint)
        announce("I have been stuck for about 30 seconds. I saved a screenshot and need you to jump in.")
    }

    private func handleBrowserUseHumanHandoff(_ event: PawscriptBrowserUseEvent) async {
        let package = activePackage
        let step = step(number: event.stepNumber) ?? currentStep
        let capture = await captureStuckContext(
            package: package,
            step: step,
            reason: "Browser Use requested human help",
            eventMessage: event.message,
            source: "agent-execution-browser-use-v1",
            force: true
        )
        if var package {
            let gotcha = SkillGotcha(
                skillId: package.skill.id,
                title: "Browser Use paused for human help",
                description: Self.describeStuckContext(message: event.message, capture: capture),
                source: "agent-execution-browser-use-v1",
                stepNumber: step?.number,
                fix: "Have the user resolve the visible blocker, then rerun or continue the skill."
            )
            package.appendUniqueGotcha(gotcha)
            package.skill.updatedAt = Date()
            activePackage = package
            try? skillStore.savePackage(package)
        }
        runState = .waitingForHuman(Self.shortText(event.message))
        browserUseHandoffActive = true
        browserUseHandoffMessage = Self.shortText(event.message)
        runLogger.updateRun(
            state: "waitingForHuman",
            package: activePackage,
            currentStep: step,
            errorSummary: Self.shortText(event.message, limit: 800)
        )
        await pointAtHumanHandoff(message: event.message, package: package, step: step)
        announce("Spanks needs a quick human pit stop. \(Self.shortText(event.message)) When you are done, say Spanks continue or press Continue.")
    }

    private func pointAtHumanHandoff(
        message: String,
        package: PawscriptSkillPackage?,
        step: SkillStep?
    ) async {
        guard let package else { return }

        let handoffStep = SkillStep(
            skillId: package.skill.id,
            number: step?.number ?? 0,
            title: "Human checkpoint",
            action: "click",
            target: "sign in, log in, continue, account, workspace, upload, asset, editor, or the visible blocker mentioned by the page",
            value: nil,
            description: message,
            verification: "The user resolves the visible blocker and asks Spanks to continue.",
            gotchaText: message
        )

        do {
            let match = try await screenMatcher.match(step: handoffStep)
            lastScreenMatch = match
            if match.hasCoordinate && match.confidence >= 0.2 {
                pointAtScreenMatchHandler?(handoffStep, match)
                addEvent(title: "Pointing at handoff", detail: match.hint)
            } else {
                pointAtCurrentStepHandler?(handoffStep)
                addEvent(title: "Handoff target unclear", detail: match.hint)
            }
        } catch {
            pointAtCurrentStepHandler?(handoffStep)
            addEvent(title: "Handoff pointing skipped", detail: error.localizedDescription)
        }
    }

    private func captureStuckContext(
        package: PawscriptSkillPackage?,
        step: SkillStep?,
        reason: String,
        eventMessage: String,
        source: String,
        force: Bool
    ) async -> PawscriptContextSnapshot? {
        guard let package else { return nil }
        let key = "\(source)-\(step?.number ?? 0)-\(reason)"
        if !force && lastCapturedStuckKey == key { return nil }
        do {
            let snapshot = try await contextCapture.capture(
                package: package,
                step: step,
                reason: reason,
                eventMessage: eventMessage,
                source: source
            )
            lastCapturedStuckKey = key
            addEvent(title: "Saved stuck context", detail: snapshot.screenshotPath)
            runLogger.addArtifact(kind: "screenshot", path: snapshot.screenshotPath)
            runLogger.addArtifact(kind: "context", path: snapshot.contextPath)
            return snapshot
        } catch {
            addEvent(title: "Context capture failed", detail: error.localizedDescription)
            return nil
        }
    }

    private func step(number: Int?) -> SkillStep? {
        guard let number, let activePackage else { return nil }
        return activePackage.steps.first { $0.number == number }
    }

    private func stepContext(_ step: SkillStep) -> String {
        [
            step.title,
            step.target,
            step.value,
            step.description,
            step.verification,
            step.gotchaText
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private static func describeStuckContext(message: String, capture: PawscriptContextSnapshot?) -> String {
        guard let capture else { return message }
        return "\(message)\nScreenshot: \(capture.screenshotPath)\nContext: \(capture.contextPath)"
    }

    private static func shortText(_ text: String, limit: Int = 220) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        let end = compact.index(compact.startIndex, offsetBy: limit)
        return String(compact[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

private extension PawscriptSkillPackage {
    mutating func appendUniqueGotcha(_ gotcha: SkillGotcha) {
        let alreadySaved = gotchas.contains { existing in
            existing.source == gotcha.source &&
            existing.title == gotcha.title &&
            existing.description == gotcha.description &&
            existing.stepNumber == gotcha.stepNumber
        }

        if !alreadySaved {
            gotchas.append(gotcha)
        }
    }
}
