import Foundation
import Observation
import SwiftUI

enum CaptionTheme: String, CaseIterable, Codable {
    /// Black fill, white text. YouTube default.
    case dark
    /// White fill, black text.
    case light

    var displayName: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    var fill: Color { self == .dark ? .black : .white }
    var text: Color { self == .dark ? .white : .black }
}

/// UserDefaults-backed preferences.
@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var localeIdentifier: String {
        didSet { defaults.set(localeIdentifier, forKey: Keys.locale) }
    }
    var theme: CaptionTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }
    var engineKind: EngineKind {
        didSet { defaults.set(engineKind.rawValue, forKey: Keys.engine) }
    }

    /// Opacities from the product spec: fill 40%, text 80%.
    let fillOpacity: Double = 0.4
    let textOpacity: Double = 0.8
    let maxLines = 2

    var locale: Locale { Locale(identifier: localeIdentifier) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? Locale.current.identifier
        theme = CaptionTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .dark
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 26
        engineKind = EngineKind(rawValue: defaults.string(forKey: Keys.engine) ?? "") ?? .speechAnalyzer
    }

    private enum Keys {
        static let locale = "captions.locale"
        static let theme = "captions.theme"
        static let fontSize = "captions.fontSize"
        static let engine = "captions.engine"
    }
}
