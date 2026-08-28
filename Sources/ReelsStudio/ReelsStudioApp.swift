import SwiftUI
import KadrAudio

@main
struct ReelsStudioApp: App {

    /// v0.6 Tier 8 — boot Sentry at the earliest possible call site so app-
    /// launch crashes are captured. No-op when no DSN is configured.
    /// `_` so the compiler doesn't strip the side effect.
    private static let _crashReportingBoot: Bool = {
        Task { @MainActor in CrashReporter.startIfConfigured(enabled: AppSettings.shared.crashReportingEnabled) }
        return true
    }()

    /// v0.12 — configure the audio session before anything can play.
    ///
    /// Without this the app runs under `.soloAmbient`, iOS's default, which obeys
    /// the ring/silent switch: **a muted phone made the editor preview silent**,
    /// with nothing on screen saying why. Every video app ignores that switch,
    /// which is why nobody expects a preview to obey it.
    ///
    /// Configured at launch and activated per preview, not here: activating takes
    /// audio focus, and doing that at launch would stop the user's music for as
    /// long as the app is open.
    private static let _audioSessionBoot: Bool = {
        try? AudioSession.configure(.preview)
        return true
    }()

    /// Single library instance for the app's lifetime. Built on first access
    /// so a `FileManager` failure doesn't crash launch — we surface it as an
    /// in-app alert via ``LibraryHostView`` instead.
    @State private var libraryHost = LibraryHost()

    /// App-wide error surfacing. Mounted at the root via ``View/toastHost(_:)``
    /// so every screen pushed onto the navigation stack inherits the toast
    /// banner / resumable sheet / catastrophic alert presentation without
    /// re-installing the modifier.
    @State private var toastCenter = ToastCenter()

    /// App-wide preferences (haptic strength today; more in v0.5+). Owned
    /// at the root so every screen can read via `@Environment(AppSettings.self)`.
    /// `HapticEngine` reaches `AppSettings.shared` directly so haptic
    /// gating works from non-View contexts (gesture handlers).
    @State private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            LibraryHostView(host: libraryHost)
                .environment(toastCenter)
                .environment(settings)
                .toastHost(toastCenter)
        }
    }
}

/// Owns the lazy `ProjectLibrary` construction so `App` can stay declarative.
/// If `ProjectLibrary.init()` throws (App Support directory not creatable,
/// permission failure on first launch), we surface `setupError` instead of
/// hanging the UI.
@MainActor
@Observable
final class LibraryHost {
    var library: ProjectLibrary?
    var setupError: String?

    init() {
        // v0.6 Tier 6 — XCUITests pass `--ui-test-reset` so each run starts
        // from an empty library. Guard via DEBUG so a release build can't
        // accidentally wipe a real user's projects even if the flag were
        // somehow forwarded.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reset") {
            try? ProjectLibrary.wipeDefaultDirectory()
        }
        #endif
        do {
            self.library = try ProjectLibrary()
        } catch {
            self.setupError = ErrorSanitizer.sanitize(error)
        }
    }
}

struct LibraryHostView: View {

    var host: LibraryHost

    @Environment(\.reelPalette) private var palette

    var body: some View {
        if let library = host.library {
            ProjectListView(library: library)
        } else {
            // Same centred column the library's empty state uses: glyph,
            // heading, explainer — leading-aligned inside a measured column.
            VStack(alignment: .leading, spacing: Reel.Space.s4) {
                // Decision 4 — the scheme has no warning role; the accent is
                // the one thing that flags a problem.
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: Reel.Typography.Glyph.lg, weight: Reel.Typography.headingWeight))
                    .foregroundStyle(palette.accent)
                Text("Couldn't open project library")
                    .reelHeading(Reel.Typography.h4)
                if let message = host.setupError {
                    Text(message)
                        .reelBody()
                        .foregroundStyle(palette.textMuted)
                }
            }
            .frame(maxWidth: Reel.emptyStateMeasure, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Reel.Space.s4)
            // v0.8 Tier 2 — the library-failure screen is app chrome; chrome
            // is the print ground. The happy path is `ProjectListView`, which
            // establishes the same ground at its own root.
            .reelSurface(.print)
        }
    }
}
