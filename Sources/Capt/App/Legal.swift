import AppKit

/// Links behind the Legal and Source rows.
enum Legal {
    static let sourceCode = URL(string: "https://github.com/vznh/capt")!
    static let privacyPolicy = URL(string: "https://github.com/vznh/capt/blob/master/PRIVACY.md")!
    static let termsAndConditions = URL(string: "https://github.com/vznh/capt/blob/master/TERMS.md")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
