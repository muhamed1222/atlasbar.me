import SwiftUI

struct CodexMarkView: View {
    enum Size {
        case compact
        case regular
        case prominent

        var container: CGFloat {
            switch self {
            case .compact:
                return 18
            case .regular:
                return 22
            case .prominent:
                return 26
            }
        }

        var glyph: CGFloat {
            switch self {
            case .compact:
                return 10
            case .regular:
                return 12
            case .prominent:
                return 14
            }
        }
    }

    enum Style {
        case standard
        case elevated

        var gradientColors: [Color] {
            switch self {
            case .standard:
                return [Color.blue.opacity(0.12), Color.cyan.opacity(0.1)]
            case .elevated:
                return [Color.blue.opacity(0.24), Color.cyan.opacity(0.18)]
            }
        }

        var borderColor: Color {
            switch self {
            case .standard:
                return Color.clear
            case .elevated:
                return Color.white.opacity(0.08)
            }
        }

        var glyphColor: Color {
            switch self {
            case .standard:
                return Color.blue.opacity(0.84)
            case .elevated:
                return Color.blue.opacity(0.96)
            }
        }

        var centerFill: Color {
            switch self {
            case .standard:
                return Color.white.opacity(0.95)
            case .elevated:
                return Color.white.opacity(0.98)
            }
        }

        var centerStroke: Color {
            switch self {
            case .standard:
                return glyphColor.opacity(0.24)
            case .elevated:
                return glyphColor.opacity(0.3)
            }
        }
    }

    var size: Size = .compact
    var style: Style = .standard

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: style.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.container, height: size.container)
                .overlay(
                    Circle()
                        .stroke(style.borderColor, lineWidth: 1)
                )

            CodexGlyphView(style: style)
                .frame(width: size.glyph, height: size.glyph)
        }
        .accessibilityHidden(true)
    }
}

private struct CodexGlyphView: View {
    let style: CodexMarkView.Style

    var body: some View {
        ZStack {
            ForEach([0.0, 60.0, 120.0], id: \.self) { angle in
                RoundedRectangle(cornerRadius: 2.35, style: .continuous)
                    .stroke(
                        style.glyphColor,
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 8.6, height: 4.9)
                    .rotationEffect(.degrees(angle))
            }

            Circle()
                .fill(style.centerFill)
                .frame(width: 2.35, height: 2.35)

            Circle()
                .stroke(style.centerStroke, lineWidth: 0.45)
                .frame(width: 2.35, height: 2.35)
        }
    }
}
