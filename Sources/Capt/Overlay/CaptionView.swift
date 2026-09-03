import CaptionCore
import SwiftUI

/// Roll-up caption block pinned to the bottom of the overlay. Fixed width and a reserved two-line
/// height so text appears in place instead of the box growing and re-centering as words arrive.
struct CaptionView: View {
    let store: CaptionStore
    let settings: SettingsStore

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    /// System accessibility settings override the 40% / 80% defaults.
    private var fillOpacity: Double { reduceTransparency ? 0.9 : settings.fillOpacity }
    private var textOpacity: Double { contrast == .increased ? 1.0 : settings.textOpacity }
    private var edgeOpacity: Double { contrast == .increased ? 1.0 : 0.6 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if !store.displayText.isEmpty {
                Text(store.displayText)
                    .font(.system(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(settings.theme.text.opacity(textOpacity))
                    // Text edge keeps glyphs legible where the translucent fill sits over bright or busy video.
                    .shadow(color: settings.theme.fill.opacity(edgeOpacity), radius: 1, x: 0, y: 1)
                    .lineSpacing(settings.fontSize * 0.15)
                    .multilineTextAlignment(.leading)
                    .lineLimit(settings.maxLines, reservesSpace: true)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        settings.theme.fill.opacity(fillOpacity),
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                    )
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
        .transaction { $0.animation = nil }
    }
}
