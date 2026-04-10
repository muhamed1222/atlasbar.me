import SwiftUI

struct LimitBarLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Size {
        case compact
        case regular

        var side: CGFloat {
            switch self {
            case .compact:
                return 18
            case .regular:
                return 22
            }
        }
    }

    var size: Size = .compact

    var body: some View {
        Group {
            Image("LimitBarLogoSymbol")
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.88) : Color.white.opacity(0.96))
                .frame(width: size.side, height: size.side)
        }
        .accessibilityHidden(true)
    }
}

struct ProviderMarkView: View {
    let provider: Provider
    var size: CodexMarkView.Size = .compact
    var style: CodexMarkView.Style = .standard

    var body: some View {
        if provider.isClaude {
            ClaudeMarkView(size: size, style: style)
        } else {
            CodexMarkView(size: size, style: style)
        }
    }
}

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
        case accountList
        case elevated
        case menuBar
        case menuBarGlyph
        case glyphOnly

        private var codexBlue: Color {
            Color(red: 0, green: 0.6, blue: 1)
        }

        var gradientColors: [Color] {
            switch self {
            case .standard:
                return [Color.blue.opacity(0.12), Color.cyan.opacity(0.1)]
            case .accountList:
                return [codexBlue.opacity(0.12), codexBlue.opacity(0.12)]
            case .elevated:
                return [Color.blue.opacity(0.24), Color.cyan.opacity(0.18)]
            case .menuBar:
                return [Color.white, Color.white.opacity(0.96)]
            case .menuBarGlyph:
                return [.clear, .clear]
            case .glyphOnly:
                return [.clear, .clear]
            }
        }

        var borderColor: Color {
            switch self {
            case .standard:
                return Color.clear
            case .accountList:
                return Color.clear
            case .elevated:
                return Color.white.opacity(0.08)
            case .menuBar:
                return Color.black.opacity(0.14)
            case .menuBarGlyph:
                return Color.clear
            case .glyphOnly:
                return Color.clear
            }
        }

        var glyphColor: Color {
            switch self {
            case .standard:
                return Color.black.opacity(0.96)
            case .accountList:
                return codexBlue
            case .elevated:
                return Color.black.opacity(0.96)
            case .menuBar:
                return Color.black.opacity(0.9)
            case .menuBarGlyph:
                return .white
            case .glyphOnly:
                return .white
            }
        }

        var glyphScale: CGFloat {
            switch self {
            case .accountList:
                return 1.24
            case .menuBarGlyph:
                return 1.26
            default:
                return 1
            }
        }

        var glyphPadding: CGFloat {
            switch self {
            case .menuBarGlyph:
                return 0.08
            case .glyphOnly:
                return 0.1
            default:
                return 0.2
            }
        }
    }

    var size: Size = .compact
    var style: Style = .standard

    var body: some View {
        Group {
            if style == .glyphOnly || style == .accountList || style == .menuBarGlyph {
                CodexGlyphView(style: style)
                    .frame(width: size.container, height: size.container)
                    .frame(width: size.container, height: size.container)
            } else {
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
                        .frame(width: size.container - 1, height: size.container - 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CodexGlyphView: View {
    let style: CodexMarkView.Style

    var body: some View {
        CodexGlyphShape()
            .fill(style.glyphColor)
            .padding(style.glyphPadding)
            .scaleEffect(style.glyphScale)
    }
}

private struct CodexGlyphShape: Shape {
    private static let sourceRect = CGRect(x: 0, y: 0, width: 512, height: 512)
    private static let pathData = "M191.928 67.0388C207.698 60.558 224.863 58.2193 241.792 60.2451C263.614 62.7498 283.062 72.0318 300.136 88.0747C300.366 88.2925 300.646 88.4499 300.952 88.5327C301.258 88.6156 301.579 88.6213 301.888 88.5495C324.937 82.8853 347.103 84.8825 368.368 94.541L369.399 95.0321L371.92 96.2763C394.135 107.785 410.063 125.252 419.689 148.629C424.24 159.744 426.532 171.351 426.581 183.432C426.902 192.428 425.909 201.423 423.634 210.132C423.522 210.576 423.523 211.041 423.638 211.484C423.752 211.928 423.976 212.335 424.289 212.67C437.159 225.717 446.109 242.114 450.121 259.996C456.424 291.116 449.958 319.175 430.755 344.14L427.776 347.741C415.059 362.304 398.365 372.836 379.745 378.043C379.339 378.16 378.966 378.373 378.658 378.663C378.351 378.954 378.117 379.313 377.977 379.713C373.803 391.761 369.612 402.042 361.82 412.322C342.192 438.22 313.331 452.626 280.819 452.446C254.905 452.315 231.937 442.837 211.9 424.027C211.596 423.748 211.225 423.553 210.823 423.462C210.421 423.37 210.003 423.384 209.608 423.503C201.128 426.237 192.583 426.63 183.35 426.532C168.599 426.413 154.071 422.93 140.869 416.349C127.051 409.495 115.022 399.512 105.738 387.194C102.415 382.79 99.1245 378.649 96.718 373.754C93.3991 367.007 90.6873 359.978 88.6147 352.751C84.2631 336.326 84.1673 319.064 88.3364 302.592C88.4712 302.203 88.516 301.789 88.4674 301.38C88.3863 300.974 88.1734 300.606 87.8617 300.333C77.7707 290.126 70.0568 277.817 65.2706 264.285C62.1017 255.954 60.2621 247.176 59.8192 238.273C59.0276 226.55 60.0659 214.775 62.8969 203.371C70.2635 179.078 84.3257 160.022 105.083 146.189C109.7 143.112 114.087 140.722 118.212 139.019C122.894 137.055 127.593 135.418 132.307 134.043C132.644 133.943 132.951 133.76 133.2 133.511C133.449 133.263 133.631 132.956 133.731 132.618C137.307 119.767 143.455 107.776 151.804 97.3731C162.936 83.5238 176.311 73.4069 191.928 67.0388ZM178.766 195.546C176.938 192.348 173.915 190.008 170.362 189.039C166.808 188.071 163.015 188.553 159.818 190.381C156.62 192.209 154.279 195.232 153.311 198.786C152.342 202.34 152.825 206.132 154.653 209.33L182.384 257.868L154.751 304.491C153.057 307.65 152.649 311.342 153.612 314.795C154.576 318.248 156.836 321.195 159.921 323.02C163.006 324.846 166.677 325.409 170.168 324.592C173.658 323.775 176.698 321.64 178.652 318.635L210.41 265.071C211.663 262.959 212.333 260.552 212.353 258.096C212.373 255.641 211.742 253.223 210.525 251.091L178.766 195.546ZM267.919 297.697C264.382 297.908 261.059 299.461 258.63 302.04C256.2 304.619 254.847 308.028 254.847 311.571C254.847 315.114 256.2 318.524 258.63 321.102C261.059 323.681 264.382 325.234 267.919 325.445H347.283C350.848 325.272 354.21 323.734 356.672 321.149C359.134 318.565 360.507 315.132 360.507 311.563C360.507 307.993 359.134 304.561 356.672 301.977C354.21 299.392 350.848 297.854 347.283 297.681H267.919V297.697Z"

    func path(in rect: CGRect) -> Path {
        var path = SVGPathParser.parse(Self.pathData)
        let source = Self.sourceRect
        let scale = min(rect.width / source.width, rect.height / source.height)
        let fittedWidth = source.width * scale
        let fittedHeight = source.height * scale
        let tx = rect.midX - fittedWidth / 2 - source.minX * scale
        let ty = rect.midY - fittedHeight / 2 - source.minY * scale
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
        path = path.applying(transform)
        return path
    }
}

private struct ClaudeMarkView: View {
    let size: CodexMarkView.Size
    let style: CodexMarkView.Style

    private var surfaceFill: Color {
        switch style {
        case .standard:
            return Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.12)
        case .accountList:
            return Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.12)
        case .elevated:
            return Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.2)
        case .menuBar:
            return Color.white
        case .menuBarGlyph:
            return Color.clear
        case .glyphOnly:
            return Color.clear
        }
    }

    private var surfaceStroke: Color {
        switch style {
        case .standard:
            return Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.16)
        case .accountList:
            return Color(red: 0.85, green: 0.47, blue: 0.34).opacity(0.16)
        case .elevated:
            return Color.white.opacity(0.08)
        case .menuBar:
            return Color.black.opacity(0.14)
        case .menuBarGlyph:
            return Color.clear
        case .glyphOnly:
            return Color.clear
        }
    }

    private var glyphFill: Color {
        switch style {
        case .glyphOnly, .menuBarGlyph:
            return .white
        case .accountList:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .menuBar:
            return Color.black.opacity(0.9)
        case .standard, .elevated:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        }
    }

    private var glyphScale: CGFloat {
        switch style {
        case .menuBarGlyph:
            return 1.08
        default:
            return 1
        }
    }

    private var glyphPadding: CGFloat {
        switch style {
        case .menuBarGlyph:
            return 0.06
        default:
            return 0
        }
    }

    var body: some View {
        Group {
            if style == .glyphOnly || style == .accountList || style == .menuBarGlyph {
                ClaudeGlyphShape()
                    .fill(glyphFill)
                    .padding(glyphPadding)
                    .scaleEffect(glyphScale)
                    .frame(width: size.container, height: size.container)
                    .frame(width: size.container, height: size.container)
            } else {
                ZStack {
                    Circle()
                        .fill(surfaceFill)
                        .frame(width: size.container, height: size.container)
                        .overlay(
                            Circle()
                                .stroke(surfaceStroke, lineWidth: 1)
                        )

                    ClaudeGlyphShape()
                        .fill(glyphFill)
                        .frame(width: size.glyph + 1, height: size.glyph + 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct ClaudeGlyphShape: Shape {
    private static let sourceRect = CGRect(x: 6.2, y: 6.19995, width: 235.6, height: 235.6)
    private static let pathData = "M52.4285 162.873L98.7844 136.879L99.5485 134.602L98.7844 133.334H96.4921L88.7237 132.862L62.2346 132.153L39.3113 131.207L17.0249 130.026L11.4214 128.844L6.2 121.873L6.7094 118.447L11.4214 115.257L18.171 115.847L33.0711 116.911L55.485 118.447L71.6586 119.392L95.728 121.873H99.5485L100.058 120.337L98.7844 119.392L97.7656 118.447L74.5877 102.732L49.4995 86.1905L36.3823 76.62L29.3779 71.7757L25.8121 67.2858L24.2839 57.3608L30.6515 50.2716L39.3113 50.8623L41.4763 51.4531L50.2636 58.1879L68.9842 72.7209L93.4357 90.6804L97.0015 93.6343L98.4374 92.6652L98.6571 91.9801L97.0015 89.2625L83.757 65.2772L69.621 40.8192L63.2534 30.6579L61.5978 24.632C60.9565 22.1032 60.579 20.0111 60.579 17.4246L67.8381 7.49965L71.9133 6.19995L81.7193 7.49965L85.7946 11.0443L91.9074 24.9865L101.714 46.8451L116.996 76.62L121.453 85.4816L123.873 93.6343L124.764 96.1155H126.292V94.6976L127.566 77.9197L129.858 57.3608L132.15 30.8942L132.915 23.4505L136.608 14.4708L143.994 9.62643L149.725 12.344L154.437 19.0788L153.8 23.4505L150.998 41.6463L145.522 70.1215L141.957 89.2625H143.994L146.414 86.7813L156.093 74.0206L172.266 53.698L179.398 45.6635L187.803 36.802L193.152 32.5484H203.34L210.726 43.6549L207.415 55.1159L196.972 68.3492L188.312 79.5739L175.896 96.2095L168.191 109.585L168.882 110.689L170.738 110.53L198.755 104.504L213.91 101.787L231.994 98.7149L240.144 102.496L241.036 106.395L237.852 114.311L218.495 119.037L195.826 123.645L162.07 131.592L161.696 131.893L162.137 132.547L177.36 133.925L183.855 134.279H199.774L229.447 136.524L237.215 141.605L241.8 147.867L241.036 152.711L229.065 158.737L213.019 154.956L175.45 145.977L162.587 142.787H160.805V143.85L171.502 154.366L191.242 172.089L215.82 195.011L217.094 200.682L213.91 205.172L210.599 204.699L188.949 188.394L180.544 181.069L161.696 165.118H160.422V166.772L164.752 173.152L187.803 207.771L188.949 218.405L187.294 221.832L181.308 223.959L174.813 222.777L161.187 203.754L147.305 182.486L136.098 163.345L134.745 164.2L128.075 235.42L125.019 239.082L117.887 241.8L111.902 237.31L108.718 229.984L111.902 215.452L115.722 196.547L118.779 181.541L121.58 162.873L123.291 156.636L123.14 156.219L121.773 156.449L107.699 175.752L86.304 204.699L69.3663 222.777L65.291 224.431L58.2867 220.768L58.9235 214.27L62.8713 208.48L86.304 178.705L100.44 160.155L109.551 149.507L109.462 147.967L108.959 147.924L46.6977 188.512L35.6182 189.93L30.7788 185.44L31.4156 178.115L33.7079 175.752L52.4285 162.873Z"

    func path(in rect: CGRect) -> Path {
        var path = SVGPathParser.parse(Self.pathData)
        let source = Self.sourceRect
        let scale = min(rect.width / source.width, rect.height / source.height)
        let fittedWidth = source.width * scale
        let fittedHeight = source.height * scale
        let tx = rect.midX - fittedWidth / 2 - source.minX * scale
        let ty = rect.midY - fittedHeight / 2 - source.minY * scale
        let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
        path = path.applying(transform)
        return path
    }
}

private enum SVGPathParser {
    static func parse(_ string: String) -> Path {
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = CharacterSet(charactersIn: " ,\n\t\r")

        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero

        while !scanner.isAtEnd {
            guard let command = scanner.scanCharacter() else { break }
            switch command {
            case "M":
                let point = CGPoint(x: scanDouble(scanner), y: scanDouble(scanner))
                path.move(to: point)
                current = point
                start = point
            case "L":
                let point = CGPoint(x: scanDouble(scanner), y: scanDouble(scanner))
                path.addLine(to: point)
                current = point
            case "H":
                let point = CGPoint(x: scanDouble(scanner), y: current.y)
                path.addLine(to: point)
                current = point
            case "V":
                let point = CGPoint(x: current.x, y: scanDouble(scanner))
                path.addLine(to: point)
                current = point
            case "C":
                let c1 = CGPoint(x: scanDouble(scanner), y: scanDouble(scanner))
                let c2 = CGPoint(x: scanDouble(scanner), y: scanDouble(scanner))
                let point = CGPoint(x: scanDouble(scanner), y: scanDouble(scanner))
                path.addCurve(to: point, control1: c1, control2: c2)
                current = point
            case "Z":
                path.closeSubpath()
                current = start
            default:
                break
            }
        }

        return path
    }

    private static func scanDouble(_ scanner: Scanner) -> CGFloat {
        CGFloat(scanner.scanDouble() ?? 0)
    }
}
