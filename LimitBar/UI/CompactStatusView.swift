import AppKit
import SwiftUI

struct CompactStatusView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Image(
            nsImage: CompactStatusLabelRenderer.image(
                items: compactMenuBarItems(
                    accounts: appModel.accounts,
                    snapshots: appModel.snapshots,
                    language: appModel.resolvedLanguage
                )
            )
        )
        .renderingMode(.template)
    }
}

@MainActor
private enum CompactStatusLabelRenderer {
    private static let iconSize = NSSize(width: 15, height: 15)
    private static let itemSpacing: CGFloat = 5

    private static var cachedItems: [CompactMenuBarItem] = []
    private static var cachedImage: NSImage?

    static func image(items: [CompactMenuBarItem]) -> NSImage {
        if items == cachedItems, let cached = cachedImage {
            return cached
        }
        let rendered = renderImage(items: items)
        cachedItems = items
        cachedImage = rendered
        return rendered
    }

    private static func renderImage(items: [CompactMenuBarItem]) -> NSImage {
        let renderer = ImageRenderer(
            content:
                HStack(spacing: itemSpacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: itemSpacing) {
                            Image(nsImage: iconImage(for: item.provider))
                            Text(item.label)
                                .font(.system(size: 12.5, weight: .medium))
                                .monospacedDigit()
                        }
                    }
                }
                .foregroundStyle(Color.black)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        if let image = renderer.nsImage {
            image.isTemplate = true
            return image
        }

        let fallback = NSImage(size: NSSize(width: 96, height: 18))
        fallback.isTemplate = true
        return fallback
    }

    private static func iconImage(for provider: Provider) -> NSImage {
        let renderer = ImageRenderer(
            content: ProviderMarkView(provider: provider, size: .compact, style: .menuBarGlyph)
                .foregroundStyle(Color.black)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        if let image = renderer.nsImage {
            return resized(image: image, to: iconSize, isTemplate: true)
        }

        let fallback = NSImage(size: iconSize)
        fallback.isTemplate = true
        return fallback
    }

    private static func resized(image: NSImage, to size: NSSize, isTemplate: Bool) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        resized.unlockFocus()
        resized.isTemplate = isTemplate
        return resized
    }
}
