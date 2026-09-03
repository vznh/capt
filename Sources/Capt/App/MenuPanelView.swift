import SwiftUI

/// Control-center style panel shown from the menu bar icon, modeled on the Wi-Fi panel:
/// title with a switch on the right, then grouped rows.
struct MenuPanelView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()
            languageSection
            PanelDivider()
            appearanceSection
            PanelDivider()
            PanelRow(title: "Permissions", trailingSymbol: "arrow.up.forward.square") {
                PermissionCenter.openSystemAudioRecordingSettings()
            }
            PanelRow(title: "Quit Capt", trailingSymbol: nil) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 300)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Capt")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Toggle("Capt", isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.regular)
            }
            Text(model.statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Language")
            Picker("Language", selection: Binding(
                get: { model.selectedLocaleTag },
                set: { model.selectLocale(tag: $0) }
            )) {
                ForEach(model.supportedLocales, id: \.identifier) { locale in
                    Text(model.localeName(locale)).tag(locale.identifier(.bcp47))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Appearance")
            Picker("Theme", selection: Binding(
                get: { model.settings.theme },
                set: { model.settings.theme = $0 }
            )) {
                ForEach(CaptionTheme.allCases, id: \.self) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text("Text size")
                Spacer()
                Stepper(
                    value: Binding(
                        get: { model.settings.fontSize },
                        set: { model.settings.fontSize = $0 }
                    ),
                    in: 14...48,
                    step: 2
                ) {
                    Text("\(Int(model.settings.fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct PanelDivider: View {
    var body: some View {
        Divider().padding(.horizontal, 14)
    }
}

/// Full-width clickable row with hover highlight and an optional trailing symbol.
private struct PanelRow: View {
    let title: String
    let trailingSymbol: String?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let trailingSymbol {
                    Image(systemName: trailingSymbol)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.08) : .clear)
        .onHover { hovering = $0 }
    }
}
