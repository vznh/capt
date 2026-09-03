import Foundation
import Observation
import SwiftUI

enum CaptionTheme: String, CaseIterable, Codable {
    /// Follows the macOS appearance: dark captions in Dark Mode, light captions in Light Mode.
    case system
    /// Black fill, white text. YouTube default.
    case dark
    /// White fill, black text.
    case light

    var displayName: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// The concrete theme to draw with, given the current color scheme.
    func resolved(for scheme: ColorScheme) -> CaptionTheme {
        switch self {
        case .system: scheme == .dark ? .dark : .light
        case .dark, .light: self
        }
    }

    func fill(for scheme: ColorScheme) -> Color {
        resolved(for: scheme) == .dark ? .black : .white
    }

    func text(for scheme: ColorScheme) -> Color {
        resolved(for: scheme) == .dark ? .white : .black
    }
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

    var fillOpacity: Double {
        didSet { defaults.set(fillOpacity, forKey: Keys.fillOpacity) }
    }

    var textOpacity: Double {
        didSet { defaults.set(textOpacity, forKey: Keys.textOpacity) }
    }

    var bionicReadingEnabled: Bool {
        didSet { defaults.set(bionicReadingEnabled, forKey: Keys.bionicReading) }
    }

    /// Words transcribed across all sessions. Shown as an easter egg while holding Command.
    var totalWordCount: Int {
        didSet { defaults.set(totalWordCount, forKey: Keys.totalWords) }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? Locale.current.identifier
        theme = CaptionTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 26
        engineKind = EngineKind(rawValue: defaults.string(forKey: Keys.engine) ?? "") ?? .speechAnalyzer
        fillOpacity = Self.storedOpacity(defaults, key: Keys.fillOpacity, fallback: 0.4)
        textOpacity = Self.storedOpacity(defaults, key: Keys.textOpacity, fallback: 0.8)
        bionicReadingEnabled = defaults.bool(forKey: Keys.bionicReading)
        totalWordCount = defaults.integer(forKey: Keys.totalWords)
    }

    private static func storedOpacity(_ defaults: UserDefaults, key: String, fallback: Double) -> Double {
        guard let value = defaults.object(forKey: key) as? Double, value.isFinite else {
            return fallback
        }
        return min(max(value, 0), 1)
    }

    private enum Keys {
        static let locale = "captions.locale"
        static let theme = "captions.theme"
        static let fontSize = "captions.fontSize"
        static let engine = "captions.engine"
        static let fillOpacity = "captions.fillOpacity"
        static let textOpacity = "captions.textOpacity"
        static let bionicReading = "captions.bionicReading"
        static let totalWords = "captions.totalWords"
    }
}
