import CaptionCore
import SwiftUI

/// Roll-up caption block pinned to the bottom of the overlay. Fixed width and a reserved two-line
/// height so text appears in place instead of the box growing and re-centering as words arrive.
struct CaptionView: View {
    let store: CaptionStore
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if !store.displayText.isEmpty {
                Text(store.displayText)
                    .font(.system(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(settings.theme.text.opacity(settings.textOpacity))
                    .lineSpacing(settings.fontSize * 0.15)
                    .multilineTextAlignment(.leading)
                    .lineLimit(settings.maxLines, reservesSpace: true)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        settings.theme.fill.opacity(settings.fillOpacity),
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
