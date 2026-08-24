import Foundation

/// Tiered application-error model. Severity drives presentation:
/// - ``transient`` → top-anchored toast, auto-dismiss after 2s, no action
/// - ``resumable`` → inline sheet with Retry / Cancel
/// - ``catastrophic`` → full alert with "OK" (and optionally a recovery action)
///
/// Mirrors the CapCut / VN / iMovie error-surfacing tiers from the v0.2 RFC.
enum AppError: Sendable {

    /// Recoverable failure with no user action required. Photo resolution
    /// failed for one item, file format unsupported, trim out of bounds.
    case transient(message: String, detail: String? = nil)

    /// Resumable failure — the user can retry and may succeed. Auto-save
    /// failed, export failed, file load failed transiently.
    case resumable(
        message: String,
        retry: @Sendable @MainActor () async -> Void
    )

    /// Catastrophic failure that warrants a full alert. Project corrupt,
    /// can't reach Photos library, library directory unwritable.
    case catastrophic(message: String, detail: String? = nil)

    /// User-facing primary message. Identical across all severities.
    var message: String {
        switch self {
        case .transient(let m, _),
             .resumable(let m, _),
             .catastrophic(let m, _):
            return m
        }
    }

    /// Optional secondary detail (e.g. underlying error description).
    var detail: String? {
        switch self {
        case .transient(_, let d), .catastrophic(_, let d):
            return d
        case .resumable:
            return nil
        }
    }
}

/// Convenience factories for common cases — keep the call sites short.
extension AppError {

    /// Wrap any `Error` into a transient toast. Pulls
    /// `.localizedDescription` for the message; pass an explicit `prefix`
    /// to disambiguate when the wrapped error is generic. v0.6 Tier 4
    /// routes the detail through ``ErrorSanitizer`` so embedded file URLs /
    /// sandbox paths never reach the toast.
    static func transient(_ error: Error, prefix: String? = nil) -> AppError {
        let text = readable(error)
        if let prefix {
            return .transient(message: prefix, detail: text.joined)
        }
        return .transient(message: text.description, detail: text.recovery)
    }

    /// Build a catastrophic error for a thrown error.
    static func catastrophic(_ error: Error, prefix: String? = nil) -> AppError {
        let text = readable(error)
        if let prefix {
            return .catastrophic(message: prefix, detail: text.joined)
        }
        return .catastrophic(message: text.description, detail: text.recovery)
    }

    /// What an error has to say for itself, in the two parts a person needs:
    /// what happened, and what to do about it.
    struct Readable: Sendable {
        /// Sanitized `localizedDescription` — always present.
        let description: String
        /// Sanitized `recoverySuggestion`, when the error offers one.
        let recovery: String?

        /// Both parts as one string, for the single-`Text` sites.
        var joined: String {
            guard let recovery else { return description }
            return "\(description) \(recovery)"
        }
    }

    /// Read an error's human-facing text.
    ///
    /// `localizedDescription` returns `errorDescription` **alone**, so the
    /// `recoverySuggestion` a `LocalizedError` writes never reaches the UI
    /// unless something asks for it. Across the kadr family that suggestion is
    /// the actionable half — "Add at least one clip before exporting." against
    /// "There's nothing to export." — and it was being dropped on the floor.
    ///
    /// Both parts go through ``ErrorSanitizer``. kadr deliberately writes its
    /// strings without file paths, but Foundation and AVFoundation errors
    /// still arrive with them embedded, and `KadrError.exportFailed`
    /// interpolates one of those verbatim.
    ///
    /// The `NSError` fallback covers errors that carry a recovery suggestion
    /// in `userInfo` without conforming to `LocalizedError` in Swift — most of
    /// Foundation.
    nonisolated static func readable(_ error: Error) -> Readable {
        let suggestion = (error as? LocalizedError)?.recoverySuggestion
            ?? (error as NSError).localizedRecoverySuggestion
        var recovery: String?
        if let suggestion, !suggestion.isEmpty {
            recovery = ErrorSanitizer.sanitize(suggestion)
        }
        return Readable(
            description: ErrorSanitizer.sanitize(error),
            recovery: recovery
        )
    }
}
