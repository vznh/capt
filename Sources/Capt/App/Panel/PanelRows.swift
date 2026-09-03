import SwiftUI

// Row building blocks for the menu bar panel.

/// Row content: title on the left, optional secondary value and a trailing symbol on the right.
struct RowLabel: View {
    let title: String
    let value: String?
    let symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(PanelFont.row)
                .lineLimit(1)
            if let value {
                Text(value)
                    .font(PanelFont.row)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            if let symbol {
                Image(systemName: symbol)
                    .font(PanelFont.chevron)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, PanelMetrics.inset)
        .frame(maxWidth: .infinity, minHeight: PanelMetrics.rowHeight, maxHeight: PanelMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

/// Rounded hover highlight inset from the panel edge, as in Control Center panels.
struct RowHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: PanelMetrics.highlightRadius, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.1 : 0))
                    .padding(.horizontal, PanelMetrics.highlightInset)
            )
            .onHover { hovering = $0 }
    }
}

/// A row that opens a menu of choices. Shows the current value and a chevron on the right.
struct MenuRow<Items: View>: View {
    let title: String
    let value: String?
    /// Trailing symbol. Rows whose value can also be scrolled use the up/down pair.
    var symbol: String = "chevron.right"
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            RowLabel(title: title, value: value, symbol: symbol)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .modifier(RowHighlight())
    }
}

/// A row that performs an action. Optional trailing symbol, e.g. open-externally.
struct ActionRow: View {
    let title: String
    let symbol: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RowLabel(title: title, value: nil, symbol: symbol)
        }
        .buttonStyle(.plain)
        .modifier(RowHighlight())
    }
}
