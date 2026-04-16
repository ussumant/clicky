//
//  SpanksSpriteView.swift
//  leanring-buddy
//
//  Pixel-cat sprite sheet renderer with a SwiftUI fallback.
//

import AppKit
import SwiftUI

enum SpanksSpriteMood {
    case idle
    case pawPoint
    case purr
    case slap
    case sleep

    var animationState: SpanksAnimationState {
        switch self {
        case .idle: return .idle
        case .pawPoint: return .pointing
        case .purr: return .speaking
        case .slap: return .error
        case .sleep: return .disabled
        }
    }

    var label: String {
        switch self {
        case .idle: return "SPANKS"
        case .pawPoint: return "POINT"
        case .purr: return "PURR"
        case .slap: return "SLAP"
        case .sleep: return "Zzz"
        }
    }
}

enum SpanksAnimationState: String, CaseIterable {
    case idle
    case listening
    case capturingScreen
    case thinking
    case speaking
    case pointing
    case waitingForHuman
    case success
    case agentRunning
    case error
    case permissionNeeded
    case disabled

    var metadata: SpanksSpriteMetadata {
        switch self {
        case .idle:
            return SpanksSpriteMetadata(fileName: "spanks-idle.png", frames: 8, fps: 7, loops: true)
        case .listening:
            return SpanksSpriteMetadata(fileName: "spanks-listening.png", frames: 6, fps: 9, loops: true)
        case .capturingScreen:
            return SpanksSpriteMetadata(fileName: "spanks-capturing-screen.png", frames: 8, fps: 9, loops: true)
        case .thinking:
            return SpanksSpriteMetadata(fileName: "spanks-thinking.png", frames: 8, fps: 7, loops: true)
        case .speaking:
            return SpanksSpriteMetadata(fileName: "spanks-speaking.png", frames: 8, fps: 12, loops: true)
        case .pointing:
            return SpanksSpriteMetadata(fileName: "spanks-pointing.png", frames: 8, fps: 10, loops: true)
        case .waitingForHuman:
            return SpanksSpriteMetadata(fileName: "spanks-waiting-for-human.png", frames: 6, fps: 5, loops: true)
        case .success:
            return SpanksSpriteMetadata(fileName: "spanks-success.png", frames: 12, fps: 12, loops: false)
        case .agentRunning:
            return SpanksSpriteMetadata(fileName: "spanks-agent-running.png", frames: 10, fps: 12, loops: true)
        case .error:
            return SpanksSpriteMetadata(fileName: "spanks-error.png", frames: 8, fps: 9, loops: false)
        case .permissionNeeded:
            return SpanksSpriteMetadata(fileName: "spanks-permission-needed.png", frames: 6, fps: 6, loops: true)
        case .disabled:
            return SpanksSpriteMetadata(fileName: "spanks-disabled.png", frames: 6, fps: 4, loops: true)
        }
    }
}

struct SpanksSpriteMetadata {
    let fileName: String
    let frames: Int
    let fps: Double
    let loops: Bool
}

struct SpanksSpriteView: View {
    private let animationState: SpanksAnimationState
    private let fallbackMood: SpanksSpriteMood
    var size: CGFloat = 64

    init(mood: SpanksSpriteMood, size: CGFloat = 64) {
        self.animationState = mood.animationState
        self.fallbackMood = mood
        self.size = size
    }

    init(animationState: SpanksAnimationState, size: CGFloat = 64) {
        self.animationState = animationState
        self.fallbackMood = animationState.fallbackMood
        self.size = size
    }

    var body: some View {
        if let spriteImage = SpanksSpriteImageCache.image(named: animationState.metadata.fileName) {
            SpanksAnimatedSpriteStrip(
                image: spriteImage,
                animationState: animationState,
                size: size
            )
        } else {
            SpanksFallbackSpriteView(mood: fallbackMood, size: size)
        }
    }
}

private struct SpanksAnimatedSpriteStrip: View {
    let image: NSImage
    let animationState: SpanksAnimationState
    let size: CGFloat

    @State private var animationStartDate = Date()

    var body: some View {
        let metadata = animationState.metadata
        TimelineView(.animation) { context in
            let frameIndex = frameIndex(at: context.date, metadata: metadata)
            ZStack(alignment: .leading) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .antialiased(false)
                    .frame(width: size * CGFloat(metadata.frames), height: size)
                    .offset(x: -CGFloat(frameIndex) * size)
            }
            .frame(width: size, height: size, alignment: .leading)
            .clipped()
            .shadow(color: Color(hex: "#60A5FA").opacity(0.55), radius: 8, x: 0, y: 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            animationStartDate = Date()
        }
        .onChange(of: animationState) { _ in
            animationStartDate = Date()
        }
    }

    private func frameIndex(at date: Date, metadata: SpanksSpriteMetadata) -> Int {
        let elapsed = max(0, date.timeIntervalSince(animationStartDate))
        let rawFrame = Int(floor(elapsed * metadata.fps))
        guard metadata.frames > 0 else { return 0 }
        if metadata.loops {
            return rawFrame % metadata.frames
        }
        return min(rawFrame, metadata.frames - 1)
    }
}

private enum SpanksSpriteImageCache {
    private static var cache: [String: NSImage] = [:]

    static func image(named fileName: String) -> NSImage? {
        if let cached = cache[fileName] { return cached }
        let baseName = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension.isEmpty ? "png" : (fileName as NSString).pathExtension

        let candidates = [
            Bundle.main.url(forResource: baseName, withExtension: ext, subdirectory: "SpanksSpriteAssets"),
            Bundle.main.resourceURL?
                .appendingPathComponent("SpanksSpriteAssets", isDirectory: true)
                .appendingPathComponent(fileName),
            Bundle.main.url(forResource: baseName, withExtension: ext)
        ]

        for url in candidates.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: url) {
                cache[fileName] = image
                return image
            }
        }

        if let image = NSImage(named: baseName) ?? NSImage(named: fileName) {
            cache[fileName] = image
            return image
        }

        return nil
    }
}

private extension SpanksAnimationState {
    var fallbackMood: SpanksSpriteMood {
        switch self {
        case .idle, .listening, .capturingScreen, .thinking, .permissionNeeded:
            return .idle
        case .speaking, .success:
            return .purr
        case .pointing, .waitingForHuman, .agentRunning:
            return .pawPoint
        case .error:
            return .slap
        case .disabled:
            return .sleep
        }
    }
}

private struct SpanksFallbackSpriteView: View {
    let mood: SpanksSpriteMood
    var size: CGFloat = 34

    var body: some View {
        VStack(spacing: max(1, size * 0.03)) {
            ZStack {
                earPair
                    .offset(y: -size * 0.22)
                face
                if mood == .pawPoint || mood == .slap {
                    paw
                        .offset(x: size * 0.34, y: size * 0.02)
                }
            }
            Text(mood.label)
                .font(.system(size: max(5, size * 0.16), weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
        }
        .frame(width: size * 1.25, height: size * 1.25)
        .shadow(color: Color(hex: "#60A5FA").opacity(0.55), radius: 8, x: 0, y: 0)
    }

    private var face: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                .fill(Color(hex: "#111827"))
                .frame(width: size * 0.86, height: size * 0.72)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                        .stroke(Color(hex: "#E5E7EB"), lineWidth: max(1, size * 0.04))
                )

            HStack(spacing: size * 0.22) {
                pixelEye
                pixelEye
            }
            .offset(y: -size * 0.06)

            mouth
                .offset(y: size * 0.14)
        }
    }

    private var earPair: some View {
        HStack(spacing: size * 0.36) {
            ear
            ear
        }
    }

    private var ear: some View {
        SpanksTriangle()
            .fill(Color(hex: "#111827"))
            .frame(width: size * 0.22, height: size * 0.22)
            .overlay(
                SpanksTriangle()
                    .stroke(Color(hex: "#E5E7EB"), lineWidth: max(1, size * 0.035))
            )
    }

    private var pixelEye: some View {
        Rectangle()
            .fill(mood == .sleep ? Color.clear : Color(hex: "#F9FAFB"))
            .frame(width: size * 0.09, height: size * 0.09)
            .overlay {
                if mood == .sleep {
                    Rectangle()
                        .fill(Color(hex: "#F9FAFB"))
                        .frame(width: size * 0.14, height: max(1, size * 0.035))
                }
            }
    }

    private var mouth: some View {
        HStack(spacing: size * 0.02) {
            Rectangle()
                .fill(Color(hex: "#F9FAFB"))
                .frame(width: size * 0.06, height: size * 0.04)
            Rectangle()
                .fill(Color(hex: "#F9FAFB"))
                .frame(width: size * 0.04, height: size * 0.08)
            Rectangle()
                .fill(Color(hex: "#F9FAFB"))
                .frame(width: size * 0.06, height: size * 0.04)
        }
    }

    private var paw: some View {
        VStack(spacing: max(1, size * 0.02)) {
            HStack(spacing: max(1, size * 0.02)) {
                pawPixel
                pawPixel
            }
            pawPixel
        }
        .rotationEffect(.degrees(mood == .slap ? -22 : 18))
    }

    private var pawPixel: some View {
        Rectangle()
            .fill(Color(hex: "#F9FAFB"))
            .frame(width: size * 0.08, height: size * 0.08)
    }
}

private struct SpanksTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let height = size * sqrt(3.0) / 2.0

        path.move(to: CGPoint(x: rect.midX, y: rect.midY - height / 1.5))
        path.addLine(to: CGPoint(x: rect.midX - size / 2, y: rect.midY + height / 3))
        path.addLine(to: CGPoint(x: rect.midX + size / 2, y: rect.midY + height / 3))
        path.closeSubpath()
        return path
    }
}
