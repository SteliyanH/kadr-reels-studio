import Foundation

/// Strips file URLs and absolute filesystem paths from error messages before
/// they reach the UI. v0.6 Tier 4.
///
/// **Why this exists.** A lot of Foundation / AVFoundation errors embed the
/// offending URL or path in `localizedDescription` — `Couldn't open file
/// /Users/alice/Library/Application Support/ReelsStudio/Projects/<uuid>.json`
/// is fine for a console log but leaks sandbox-internal paths into a toast
/// the user can screenshot. Worse, the user has no way to act on it. We rewrite
/// such fragments to a stable `[file]` token, keeping the human-readable error
/// shape but dropping the sensitive bit.
///
/// Pure and `nonisolated` so it can run from any context (toast factories,
/// Combine pipelines, background-loaded library code). Test-friendly: every
/// substitution is regex-driven and covered.
public enum ErrorSanitizer {

    /// Patterns applied in order. Each removes one shape of path-leak we've
    /// seen in practice. Compiled lazily and cached on first use.
    private static let patterns: [NSRegularExpression] = {
        [
            // file:// URLs — Foundation / AVFoundation default to encoding the
            // failing URL into `userInfo[NSURLErrorKey]` and `localizedDescription`.
            #"file://[^\s'"]+"#,
            // Absolute Unix paths under the user's home / sandbox container.
            // We deliberately don't strip every leading `/` — generic strings
            // like "/" or "/dev/null" are fine to surface.
            #"/Users/[^\s'"]+"#,
            #"/private/var/mobile/Containers/[^\s'"]+"#,
            #"/var/mobile/Containers/[^\s'"]+"#,
        ].compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    /// Replace every embedded file URL / path with the token `[file]`.
    /// Returns the original string unchanged when no pattern matches.
    public static func sanitize(_ message: String) -> String {
        var result = message
        for pattern in patterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[file]"
            )
        }
        return result
    }

    /// Convenience: sanitize `error.localizedDescription`.
    public static func sanitize(_ error: Error) -> String {
        sanitize(error.localizedDescription)
    }
}
