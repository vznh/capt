import SwiftUI

/// Control-center style panel shown from the menu bar icon, styled after the macOS Wi-Fi panel:
/// bold title with a switch on the right, secondary section headers, plain rows with trailing
/// values and chevrons, 14 pt insets, inset dividers.
struct MenuPanelView: View {
    let model: AppModel

    private static let fontSizes: [Double] = [18, 22, 26, 30, 36, 42]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()

            SectionHeader("Language")
            MenuRow(title: model.localeName(model.settings.locale), value: nil) {
                ForEach(model.supportedLocales, id: \.identifier) { locale in
                    Button(model.localeName(locale)) { model.selectLocale(locale) }
                }
            }
            PanelDivider()

            SectionHeader("Appearance")
            MenuRow(title: "Theme", value: model.settings.theme.displayName) {
                ForEach(CaptionTheme.allCases, id: \.self) { theme in
                    Button(theme.displayName) { model.settings.theme = theme }
                }
            }
            MenuRow(title: "Text Size", value: "\(Int(model.settings.fontSize)) pt") {
                ForEach(Self.fontSizes, id: \.self) { size in
                    Button("\(Int(size)) pt") { model.settings.fontSize = size }
                }
            }
            PanelDivider()

            ActionRow(title: "Permissions", symbol: "arrow.up.forward.square") {
                PermissionCenter.openSystemAudioRecordingSettings()
            }
            ActionRow(title: "Quit Capt", symbol: nil) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 300)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center) {
                Text("Capt")
                    .font(PanelFont.title)
                Spacer()
                Toggle("Capt", isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.large)
            }
            Text(model.statusText)
                .font(PanelFont.secondary)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, PanelMetrics.inset)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

// MARK: - Style tokens, measured against the Wi-Fi panel

private enum PanelMetrics {
    static let inset: CGFloat = 14
    static let rowHeight: CGFloat = 32
    static let highlightInset: CGFloat = 6
    static let highlightRadius: CGFloat = 6
}

private enum PanelFont {
    static let title = Font.system(size: 17, weight: .bold)
    static let sectionHeader = Font.system(size: 14, weight: .semibold)
    static let row = Font.system(size: 15, weight: .regular)
    static let secondary = Font.system(size: 13, weight: .regular)
    static let chevron = Font.system(size: 13, weight: .semibold)
}

private struct SectionHeader: View {
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

private struct PanelDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, PanelMetrics.inset)
            .padding(.vertical, 6)
    }
}

/// Row content: title on the left, optional secondary value and a trailing symbol on the right.
private struct RowLabel: View {
    let title: String
    let value: String?
    let symbol: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(PanelFont.row)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(PanelFont.row)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let symbol {
                Image(systemName: symbol)
                    .font(PanelFont.chevron)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, PanelMetrics.inset)
        .frame(height: PanelMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

/// Rounded hover highlight inset from the panel edge, as in Control Center panels.
private struct RowHighlight: ViewModifier {
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
private struct MenuRow<Items: View>: View {
    let title: String
    let value: String?
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            RowLabel(title: title, value: value, symbol: "chevron.right")
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .modifier(RowHighlight())
    }
}

/// A row that performs an action. Optional trailing symbol, e.g. open-externally.
private struct ActionRow: View {
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
