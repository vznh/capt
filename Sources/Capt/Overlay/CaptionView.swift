import CaptionCore
import SwiftUI

/// YouTube-style caption block pinned to the bottom of the overlay.
struct CaptionView: View {
    let store: CaptionStore
    let settings: SettingsStore

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if !store.displayText.isEmpty {
                Text(store.displayText)
                    .font(.system(size: settings.fontSize, weight: .medium))
                    .foregroundStyle(settings.theme.text.opacity(settings.textOpacity))
                    .multilineTextAlignment(.center)
                    .lineLimit(settings.maxLines)
                    .truncationMode(.head)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        settings.theme.fill.opacity(settings.fillOpacity),
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                    )
                    .animation(.easeOut(duration: 0.08), value: store.displayText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }
}
