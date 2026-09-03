import AppKit
import CaptionCore
import SwiftUI

/// Caption block pinned to the bottom of the overlay. Up to three captions stack upward as a queue,
/// while long sentences wrap naturally at word boundaries.
struct CaptionView: View {
    let store: CaptionStore
    let settings: SettingsStore

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    /// System accessibility settings override the 40% / 80% defaults.
    private var fillOpacity: Double {
        reduceTransparency ? 0.9 : settings.fillOpacity
    }

    private var textOpacity: Double {
        contrast == .increased ? 1.0 : settings.textOpacity
    }

    private var edgeOpacity: Double {
        contrast == .increased ? 1.0 : 0.6
    }

    private var lineSpacing: CGFloat {
        settings.fontSize * 0.15
    }

    /// Bounds even punctuation-free speech to the queue's three visible rows.
    private var maximumTextHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: settings.fontSize, weight: .medium)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let gaps = CGFloat(max(0, store.maxSentences - 1)) * lineSpacing
        return CGFloat(store.maxSentences) * lineHeight + gaps
    }

    /// A hard sentence boundary should also be a visual boundary. SwiftUI handles
    /// softer line wrapping within each sentence at word boundaries.
    private var stackedText: String {
        store.sentences.joined(separator: "\n")
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if !stackedText.isEmpty {
                    caption(stackedText)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .padding(.bottom, 12)
        .transaction { $0.animation = nil }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: settings.fontSize, weight: .medium))
            .foregroundStyle(settings.theme.text(for: colorScheme).opacity(textOpacity))
            // Text edge keeps glyphs legible where the translucent fill sits over bright or busy video.
            .shadow(color: settings.theme.fill(for: colorScheme).opacity(edgeOpacity), radius: 1, x: 0, y: 1)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: maximumTextHeight, alignment: .bottom)
            .clipped()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                settings.theme.fill(for: colorScheme).opacity(fillOpacity),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .accessibilityAddTraits(.updatesFrequently)
    }
}
