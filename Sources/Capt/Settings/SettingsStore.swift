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

    func fill(for scheme: ColorScheme) -> Color { resolved(for: scheme) == .dark ? .black : .white }
    func text(for scheme: ColorScheme) -> Color { resolved(for: scheme) == .dark ? .white : .black }
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
    /// Words transcribed across all sessions. Shown as an easter egg while holding Command.
    var totalWordCount: Int {
        didSet { defaults.set(totalWordCount, forKey: Keys.totalWords) }
    }

    /// Opacities from the product spec: fill 40%, text 80%.
    let fillOpacity: Double = 0.4
    let textOpacity: Double = 0.8
    let maxLines = 2

    var locale: Locale { Locale(identifier: localeIdentifier) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        localeIdentifier = defaults.string(forKey: Keys.locale) ?? Locale.current.identifier
        theme = CaptionTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .system
        fontSize = defaults.object(forKey: Keys.fontSize) as? Double ?? 26
        engineKind = EngineKind(rawValue: defaults.string(forKey: Keys.engine) ?? "") ?? .speechAnalyzer
        totalWordCount = defaults.integer(forKey: Keys.totalWords)
    }

    private enum Keys {
        static let locale = "captions.locale"
        static let theme = "captions.theme"
        static let fontSize = "captions.fontSize"
        static let engine = "captions.engine"
        static let totalWords = "captions.totalWords"
    }
}
