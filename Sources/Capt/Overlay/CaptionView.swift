import CaptionCore
import SwiftUI

/// Caption block pinned to the bottom of the overlay. The box hugs its text and is centered, so it
/// grows outward from the middle and upward from the bottom edge as words arrive. No animation.
struct CaptionView: View {
    let store: CaptionStore
    let settings: SettingsStore

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

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
                    .foregroundStyle(settings.theme.text(for: colorScheme).opacity(textOpacity))
                    // Text edge keeps glyphs legible where the translucent fill sits over bright or busy video.
                    .shadow(color: settings.theme.fill(for: colorScheme).opacity(edgeOpacity), radius: 1, x: 0, y: 1)
                    .lineSpacing(settings.fontSize * 0.15)
                    .multilineTextAlignment(.center)
                    .lineLimit(settings.maxLines)
                    .truncationMode(.head)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        settings.theme.fill(for: colorScheme).opacity(fillOpacity),
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
