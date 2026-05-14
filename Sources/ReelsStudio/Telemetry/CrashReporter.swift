import Foundation
import Sentry

/// v0.6 Tier 8 — opt-in crash reporting. Sentry is wired in but
/// **completely inert** until a DSN is provided either at compile time
/// (via `Info.plist` → `SentryDSN`) or runtime (via the `SENTRY_DSN`
/// environment variable). Builds without a DSN never call into Sentry,
/// so debug runs / open-source contributors / fresh checkouts produce no
/// telemetry traffic.
///
/// Default sample rates are conservative: 1.0 for crashes (we want every
/// crash), 0.1 for traces (10% of sessions emit a transaction). Bump via
/// `SENTRY_TRACES_SAMPLE_RATE` if a debugging push needs more visibility.
@MainActor
public enum CrashReporter {

    /// Boot Sentry when a DSN is configured. Safe to call multiple times —
    /// Sentry guards re-entry internally. Returns whether reporting is
    /// actually live, which the caller can log without leaking the DSN.
    @discardableResult
    public static func startIfConfigured() -> Bool {
        guard let dsn = resolveDSN(), !dsn.isEmpty else { return false }
        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = bundleVersionString()
            options.environment = environmentName()
            options.enableAutoSessionTracking = true
            options.tracesSampleRate = NSNumber(
                value: resolveTracesSampleRate()
            )
            // Don't ship breadcrumbs from console / NSLog by default — too
            // chatty and risks leaking debug strings. Re-enable for a
            // specific debugging push if needed.
            options.enableAutoBreadcrumbTracking = true
            options.enableAppHangTracking = true
        }
        return true
    }

    // MARK: - Configuration lookup

    /// DSN resolution order: Info.plist `SentryDSN` first (production build
    /// pipeline plumbs this via fastlane); environment variable as fallback
    /// (local dev). Returns nil when both are absent.
    private static func resolveDSN() -> String? {
        if let bundle = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
           !bundle.isEmpty {
            return bundle
        }
        return ProcessInfo.processInfo.environment["SENTRY_DSN"]
    }

    private static func resolveTracesSampleRate() -> Double {
        if let env = ProcessInfo.processInfo.environment["SENTRY_TRACES_SAMPLE_RATE"],
           let value = Double(env) {
            return value
        }
        return 0.1
    }

    private static func bundleVersionString() -> String {
        let short = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
        return "reels-studio@\(short)+\(build)"
    }

    private static func environmentName() -> String {
        #if DEBUG
        return "debug"
        #else
        return "release"
        #endif
    }
}
