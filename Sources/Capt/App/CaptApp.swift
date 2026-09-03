import SwiftUI

let kAppSubsystem = "app.capt"

@main
struct CaptApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        MenuBarExtra("Capt", systemImage: model.isEnabled ? "captions.bubble.fill" : "captions.bubble") {
            MenuPanelView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
