import AppKit
import CaptionCore
import CoreImage
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
        contrast == .increased ? 0.6 : 0.25
    }

    private var lineSpacing: CGFloat {
        settings.fontSize * (settings.bionicReadingEnabled ? 0.3 : 0.15)
    }

    private var characterSpacing: CGFloat {
        settings.bionicReadingEnabled ? settings.fontSize * 0.01 : 0
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
        captionText(text)
            .font(.system(size: settings.fontSize, weight: .medium))
            .foregroundStyle(settings.theme.text(for: colorScheme).opacity(textOpacity))
            // Text edge keeps glyphs legible where the translucent fill sits over bright or busy video.
            .shadow(color: settings.theme.fill(for: colorScheme).opacity(edgeOpacity), radius: 0.6, x: 0, y: 0.5)
            .tracking(characterSpacing)
            .lineSpacing(lineSpacing)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: maximumTextHeight, alignment: .bottom)
            .clipped()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background { captionBackground }
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder
    private var captionBackground: some View {
        if settings.invertsCaptionBackground {
            InvertedCaptionBackground(opacity: fillOpacity)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(settings.theme.fill(for: colorScheme).opacity(fillOpacity))
        }
    }

    @ViewBuilder
    private func captionText(_ text: String) -> some View {
        if settings.bionicReadingEnabled {
            Text(fixationEmphasized(text))
        } else {
            Text(text)
        }
    }

    /// Applies fixation emphasis without changing the underlying text or its accessibility value.
    private func fixationEmphasized(_ text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString() }

        var result = AttributedString()
        var cursor = text.startIndex
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byWords, .substringNotRequired]
        ) { _, range, _, _ in
            if cursor < range.lowerBound {
                append(text[cursor..<range.lowerBound], isWord: false, to: &result)
            }
            append(text[range], isWord: true, to: &result)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            append(text[cursor...], isWord: false, to: &result)
        }
        return result
    }

    private func append(_ segment: Substring, isWord: Bool, to result: inout AttributedString) {
        guard isWord else {
            var separator = AttributedString(segment)
            separator.font = .system(size: settings.fontSize, weight: .regular)
            result += separator
            return
        }

        let emphasizedCount = (segment.count + 1) / 2
        let split = segment.index(segment.startIndex, offsetBy: emphasizedCount)
        var emphasized = AttributedString(segment[..<split])
        emphasized.font = .system(size: settings.fontSize, weight: .bold)
        var remainder = AttributedString(segment[split...])
        remainder.font = .system(size: settings.fontSize, weight: .regular)
        result += emphasized
        result += remainder
    }
}

/// Uses AppKit's behind-window material as the backdrop source, then inverts that sampled image.
/// A plain layer-backed view cannot sample pixels across the transparent caption window boundary.
private struct InvertedCaptionBackground: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(frame: .zero)
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        applyInversion(to: view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        // NSVisualEffectView can rebuild its effect layers when attached to a window. Reasserting
        // the public background filter here keeps inversion on the active backdrop surface.
        applyInversion(to: view)
        view.alphaValue = opacity
    }

    private func applyInversion(to view: NSVisualEffectView) {
        guard let inversion = CIFilter(name: "CIColorInvert") else {
            view.backgroundFilters = []
            return
        }
        view.backgroundFilters = [inversion]
    }
}
