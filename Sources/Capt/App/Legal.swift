import AppKit

/// Links behind the Legal row. Placeholders until real documents exist.
enum Legal {
    static let privacyPolicy = URL(string: "https://github.com/vznh/capt/blob/master/PRIVACY.md")!
    static let termsAndConditions = URL(string: "https://github.com/vznh/capt/blob/master/TERMS.md")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
