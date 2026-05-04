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
    /// to disambiguate when the wrapped error is generic.
    static func transient(_ error: Error, prefix: String? = nil) -> AppError {
        let detail = error.localizedDescription
        if let prefix {
            return .transient(message: prefix, detail: detail)
        }
        return .transient(message: detail)
    }

    /// Build a catastrophic error for a thrown error.
    static func catastrophic(_ error: Error, prefix: String? = nil) -> AppError {
        let detail = error.localizedDescription
        if let prefix {
            return .catastrophic(message: prefix, detail: detail)
        }
        return .catastrophic(message: detail)
    }
}
