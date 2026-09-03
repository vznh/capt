import Foundation

/// A user-facing failure raised by Capt's app-layer services.
struct CaptError: LocalizedError {
    let errorDescription: String?

    init(_ description: String) {
        errorDescription = description
    }
}
