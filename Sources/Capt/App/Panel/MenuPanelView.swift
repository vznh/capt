import SwiftUI

/// Control-center style panel shown from the menu bar icon, styled after the macOS Wi-Fi panel:
/// bold title with a switch on the right, secondary section headers, plain rows with trailing
/// values and chevrons, 14 pt insets, inset dividers.
struct MenuPanelView: View {
    let model: AppModel

    private static let fontSizes: [Double] = [18, 22, 26, 30, 36, 42]

    /// Easter egg: holding Command while the panel is open shows word counts in the detail line.
    @State private var commandHeld = false
    @State private var flagsMonitor: Any?

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
            MenuRow(title: "Text Size", value: "\(Int(model.settings.fontSize)) pt", symbol: "chevron.up.chevron.down") {
                ForEach(Self.fontSizes, id: \.self) { size in
                    Button("\(Int(size)) pt") {
                        model.settings.fontSize = size
                        model.previewCaptions()
                    }
                }
            }
            .onScrollWheel(cursor: .resizeUpDown) { delta in
                model.adjustFontSize(scrollDelta: delta)
            }
            .onHover { hovering in
                hovering ? model.beginPreview() : model.endPreview()
            }
            PanelDivider()

            ActionRow(title: "Permissions", symbol: "arrow.up.forward.square") {
                PermissionCenter.openSystemAudioRecordingSettings()
            }
            ActionRow(title: "Source", symbol: "chevron.left.forwardslash.chevron.right") {
                Legal.open(Legal.sourceCode)
            }
            MenuRow(title: "Legal", value: nil) {
                Button("Privacy Policy") { Legal.open(Legal.privacyPolicy) }
                Button("Terms and Conditions") { Legal.open(Legal.termsAndConditions) }
            }
            ActionRow(title: "Quit", symbol: nil) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 300)
        .onAppear {
            commandHeld = NSEvent.modifierFlags.contains(.command)
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                commandHeld = event.modifierFlags.contains(.command)
                return event
            }
        }
        .onDisappear {
            if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
            flagsMonitor = nil
            commandHeld = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("Capt")
                        .font(PanelFont.title)
                    Text(model.activityLabel)
                        .font(PanelFont.titleDetail)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Capt", isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.regular)
                .scaleEffect(PanelMetrics.switchScale)
                .frame(width: PanelMetrics.switchSize.width, height: PanelMetrics.switchSize.height)
            }
            if commandHeld {
                Text(model.wordCountText)
                    .font(PanelFont.secondary)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            } else if let detail = model.detailText {
                Text(detail)
                    .font(PanelFont.secondary)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, PanelMetrics.inset)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
