//
//  SpanksSpriteView.swift
//  leanring-buddy
//
//  Lightweight pixel-cat renderer used by Pawscript without external assets.
//

import SwiftUI

enum SpanksSpriteMood {
    case idle
    case pawPoint
    case purr
    case slap
    case sleep

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

struct SpanksSpriteView: View {
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
        Triangle()
            .fill(Color(hex: "#111827"))
            .frame(width: size * 0.22, height: size * 0.22)
            .overlay(
                Triangle()
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
