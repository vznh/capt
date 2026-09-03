import SwiftUI

// Style tokens for the menu bar panel, measured against the macOS Wi-Fi panel.

enum PanelMetrics {
    static let inset: CGFloat = 14
    static let rowHeight: CGFloat = 28
    static let highlightInset: CGFloat = 6
    static let highlightRadius: CGFloat = 10
    /// The system switch is drawn at this fraction of its intrinsic size.
    static let switchScale: CGFloat = 0.85
    /// Layout size for the scaled switch, rounded to whole points so it stays pixel-aligned.
    static let switchSize: CGSize = {
        let control = NSSwitch()
        control.controlSize = .regular
        let size = control.intrinsicContentSize
        return CGSize(width: (size.width * switchScale).rounded(), height: (size.height * switchScale).rounded())
    }()
}

enum PanelFont {
    static let title = Font.system(size: 14, weight: .bold)
    static let titleDetail = Font.system(size: 14, weight: .regular)
    static let sectionHeader = Font.system(size: 11, weight: .semibold)
    static let row = Font.system(size: 13, weight: .regular)
    static let secondary = Font.system(size: 12, weight: .regular)
    static let chevron = Font.system(size: 12, weight: .semibold)
}

struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(PanelFont.sectionHeader)
            .foregroundStyle(.secondary)
            .padding(.horizontal, PanelMetrics.inset)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, PanelMetrics.inset)
            .padding(.vertical, 6)
    }
}
