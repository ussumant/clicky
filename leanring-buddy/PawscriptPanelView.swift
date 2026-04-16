//
//  PawscriptPanelView.swift
//  leanring-buddy
//
//  Compact menu bar panel controls for Pawscript.
//

import SwiftUI

struct PawscriptPanelView: View {
    @ObservedObject var pawscriptManager: PawscriptExecutionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sourceTabs
            sourceInput
            customizationInput
            prerequisiteChecklist
            actionButtons
            runLogRow
            skillPreview
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            SpanksSpriteView(mood: .idle, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Pawscript")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.Colors.textPrimary)
                Text("saved tutorial becomes session")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            Spacer()
            Text(pawscriptManager.runState.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(statusColor)
        }
    }

    private var sourceTabs: some View {
        HStack(spacing: 0) {
            ForEach(PawscriptSourceKind.allCases, id: \.self) { sourceKind in
                sourceTabButton(sourceKind)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
        )
    }

    private func sourceTabButton(_ sourceKind: PawscriptSourceKind) -> some View {
        let isSelected = pawscriptManager.selectedSourceKind == sourceKind
        return Button(action: {
            pawscriptManager.selectedSourceKind = sourceKind
            if sourceKind == .doc {
                pawscriptManager.sourceURL = "https://developers.openai.com/blog/designing-delightful-frontends-with-gpt-5-4"
            } else {
                pawscriptManager.sourceURL = "https://www.youtube.com/watch?v=Q_bd7BFh0XY"
            }
        }) {
            Text(sourceKind.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }

    private var sourceInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(pawscriptManager.selectedSourceKind.placeholder, text: $pawscriptManager.sourceURL)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(inputBackground)

            Button(action: pawscriptManager.loadSelectedSource) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 10, weight: .semibold))
                    Text(pawscriptManager.runState.isFailed ? "Load fallback" : "Extract skill")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if pawscriptManager.runState == .extracting {
                        ProgressView()
                            .scaleEffect(0.45)
                            .frame(width: 12, height: 12)
                    }
                }
                .foregroundColor(DS.Colors.textOnAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .fill(DS.Colors.accent)
                )
            }
            .buttonStyle(.plain)
            .pointerCursor()

            if let fallbackNotice = pawscriptManager.fallbackNotice {
                Text(fallbackNotice)
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.warningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var customizationInput: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customize")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DS.Colors.textTertiary)
            TextField("What should Spanks help you learn/do?", text: $pawscriptManager.customizationGoal)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(inputBackground)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                runButton(
                    title: "Watch Spanks do it",
                    systemImage: "play.fill",
                    isEnabled: pawscriptManager.canRun,
                    action: pawscriptManager.runWatchMe
                )
            }
            HStack(spacing: 6) {
                runButton(
                    title: "Guide me",
                    systemImage: "person.2.fill",
                    isEnabled: pawscriptManager.activePackage != nil && pawscriptManager.runState != .extracting,
                    action: pawscriptManager.startDoTogether
                )
                runButton(
                    title: "Next",
                    systemImage: "arrow.right",
                    isEnabled: pawscriptManager.activeMode == .doTogether && pawscriptManager.runState == .running,
                    action: pawscriptManager.advanceHumanStep
                )
                runButton(
                    title: "Stuck",
                    systemImage: "exclamationmark.triangle.fill",
                    isEnabled: pawscriptManager.activeMode == .doTogether && pawscriptManager.runState == .running,
                    action: { pawscriptManager.markCurrentStepStuck(source: "button") }
                )
            }
            if pawscriptManager.activeMode == .doTogether {
                HStack(spacing: 6) {
                    runButton(
                        title: pawscriptManager.canResumeGuide ? "Resume" : "Pause",
                        systemImage: pawscriptManager.canResumeGuide ? "play.fill" : "pause.fill",
                        isEnabled: pawscriptManager.canPauseGuide || pawscriptManager.canResumeGuide,
                        action: pawscriptManager.canResumeGuide ? pawscriptManager.resumeGuide : pawscriptManager.pauseGuide
                    )
                    runButton(
                        title: "Stop guide",
                        systemImage: "stop.fill",
                        isEnabled: pawscriptManager.canStopGuide,
                        action: pawscriptManager.stopGuide
                    )
                }
            }
            if pawscriptManager.activeMode == .watchMe {
                HStack(spacing: 6) {
                    runButton(
                        title: "Continue",
                        systemImage: "play.circle.fill",
                        isEnabled: pawscriptManager.canContinueBrowserUse,
                        action: pawscriptManager.continueBrowserUseAfterHumanHelp
                    )
                    runButton(
                        title: "Stop Spanks",
                        systemImage: "stop.fill",
                        isEnabled: pawscriptManager.canStopBrowserUse,
                        action: pawscriptManager.stopBrowserUse
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var prerequisiteChecklist: some View {
        if let package = pawscriptManager.activePackage {
            let prerequisites = package.effectivePrerequisites
            if !prerequisites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: pawscriptManager.needsPrerequisiteConfirmation ? "person.crop.circle.badge.exclamationmark" : "checkmark.shield")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(pawscriptManager.needsPrerequisiteConfirmation ? DS.Colors.warningText : DS.Colors.success)
                        Text("Before Spanks starts")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DS.Colors.textPrimary)
                        Spacer()
                    }

                    ForEach(prerequisites.prefix(3)) { prerequisite in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(prerequisite.isBlocking ? "Needs you" : "Heads up"): \(prerequisite.title)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(prerequisite.isBlocking ? DS.Colors.warningText : DS.Colors.textSecondary)
                                .lineLimit(1)
                            Text(prerequisite.detail)
                                .font(.system(size: 9))
                                .foregroundColor(DS.Colors.textTertiary)
                                .lineLimit(2)
                        }
                    }

                    if pawscriptManager.needsPrerequisiteConfirmation {
                        HStack(spacing: 6) {
                            Button(action: pawscriptManager.helpWithPrerequisites) {
                                HStack(spacing: 5) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text("Open & point")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(DS.Colors.textPrimary)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()

                            Button(action: pawscriptManager.confirmPrerequisites) {
                                HStack(spacing: 5) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text(package.blockingPrerequisites.first?.actionLabel ?? "I'm ready")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(DS.Colors.textOnAccent)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                                        .fill(DS.Colors.accent)
                                )
                            }
                            .buttonStyle(.plain)
                            .pointerCursor()
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .fill(Color.white.opacity(0.055))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                        .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
                )
            }
        }
    }

    private func runButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isEnabled ? DS.Colors.textPrimary : DS.Colors.disabledText)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .fill(Color.white.opacity(isEnabled ? 0.08 : 0.04))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .pointerCursor()
    }

    @ViewBuilder
    private var runLogRow: some View {
        if let latestRunLogURL = pawscriptManager.latestRunLogURL {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Run log saved")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DS.Colors.textSecondary)
                    Text(latestRunLogURL.lastPathComponent)
                        .font(.system(size: 9))
                        .foregroundColor(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: pawscriptManager.openLatestRunLog) {
                    Text("Open")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(DS.Colors.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .fill(Color.white.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var skillPreview: some View {
        if let package = pawscriptManager.activePackage {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(package.skill.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DS.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(pawscriptManager.progressLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DS.Colors.textTertiary)
                }

                if pawscriptManager.needsPrerequisiteConfirmation,
                   let prerequisite = package.blockingPrerequisites.first {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Setup checkpoint")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.warningText)
                            .lineLimit(1)
                        Text("I will open the app page and point at sign in/setup. Say \"I'm done\" with the hotkey, or reopen Clicky and confirm.")
                            .font(.system(size: 10))
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(2)
                        Text(prerequisite.title)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(DS.Colors.textTertiary)
                            .lineLimit(1)
                    }
                } else if pawscriptManager.browserUseHandoffActive {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waiting for you")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.warningText)
                            .lineLimit(1)
                        Text(pawscriptManager.browserUseHandoffMessage ?? "Resolve the visible browser blocker, then press Continue.")
                            .font(.system(size: 10))
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(2)
                        Text("Sign in or fix the page in the browser, then say \"Spanks continue\" or press Continue.")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(DS.Colors.textTertiary)
                            .lineLimit(2)
                    }
                } else if let currentStep = pawscriptManager.currentStep {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentStep.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.accentText)
                            .lineLimit(1)
                        Text(currentStep.description)
                            .font(.system(size: 10))
                            .foregroundColor(DS.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 10) {
                    metric(label: "human", value: "\(package.skill.humanCompletions)")
                    metric(label: "agent", value: "\(package.skill.agentCompletions)")
                    metric(label: "gotchas", value: "\(package.gotchas.count)")
                }

                if let latestEvent = pawscriptManager.executionEvents.first {
                    Text("\(latestEvent.title): \(latestEvent.detail)")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                        .lineLimit(2)
                }

                if let match = pawscriptManager.lastScreenMatch {
                    Text("screen: \(match.state) · \(Int(match.confidence * 100))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DS.Colors.textTertiary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(DS.Colors.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)
        }
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.medium, style: .continuous)
                    .stroke(DS.Colors.borderSubtle, lineWidth: 0.5)
            )
    }

    private var statusColor: Color {
        switch pawscriptManager.runState {
        case .completed: return DS.Colors.success
        case .failed, .waitingForHuman: return DS.Colors.warningText
        case .running, .extracting: return DS.Colors.accentText
        case .paused: return DS.Colors.textSecondary
        case .idle, .ready: return DS.Colors.textTertiary
        }
    }
}
