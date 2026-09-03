import SwiftUI

let kAppSubsystem = "app.capt"

@main
struct CaptApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        MenuBarExtra("Capt", systemImage: model.isRunning ? "captions.bubble.fill" : "captions.bubble") {
            MenuContent(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    let model: AppModel

    var body: some View {
        Text(model.statusText)
        Button(model.isRunning ? "Stop Captions" : "Start Captions") { model.toggle() }
            .keyboardShortcut("c", modifiers: [.command, .shift])

        Divider()

        Menu("Language") {
            ForEach(model.supportedLocales, id: \.identifier) { locale in
                Button {
                    model.selectLocale(locale)
                } label: {
                    let installed = model.installedLocales.contains { $0.identifier == locale.identifier }
                    Text(model.localeName(locale) + (installed ? "" : "  (download)"))
                    if locale.identifier == model.settings.localeIdentifier {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }

        Menu("Appearance") {
            ForEach(CaptionTheme.allCases, id: \.self) { theme in
                Button {
                    model.settings.theme = theme
                } label: {
                    Text(theme.displayName)
                    if theme == model.settings.theme { Image(systemName: "checkmark") }
                }
            }
            Divider()
            Button("Larger Text") { model.settings.fontSize = min(model.settings.fontSize + 2, 48) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { model.settings.fontSize = max(model.settings.fontSize - 2, 14) }
                .keyboardShortcut("-", modifiers: .command)
        }

        Button("Audio Recording Permissions…") { PermissionCenter.openSystemAudioRecordingSettings() }

        Divider()
        Button("Quit Capt") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
