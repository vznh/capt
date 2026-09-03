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
        Button(model.isRunning ? "Stop Scribing" : "Start Scribing") { model.toggle() }
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
                    // Trailing mark: native menus only place state checkmarks in the left column.
                    if theme == model.settings.theme {
                        Text(theme.displayName + "  \u{2713}")
                    } else {
                        Text(theme.displayName)
                    }
                }
            }
            Divider()
            Button("Larger Text") { model.settings.fontSize = min(model.settings.fontSize + 2, 48) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Smaller Text") { model.settings.fontSize = max(model.settings.fontSize - 2, 14) }
                .keyboardShortcut("-", modifiers: .command)
        }

        Button {
            PermissionCenter.openSystemAudioRecordingSettings()
        } label: {
            // Trailing glyph signals this leaves the app for System Settings. A text glyph, not an SF Symbol:
            // image attachments in menu titles render black regardless of theme.
            Text("Permissions \u{2197}")
        }

        Divider()
        Button("Quit Capt") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
