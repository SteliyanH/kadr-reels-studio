import SwiftUI

@main
struct ReelsStudioApp: App {

    /// Single library instance for the app's lifetime. Built on first access
    /// so a `FileManager` failure doesn't crash launch — we surface it as an
    /// in-app alert via ``LibraryHostView`` instead.
    @StateObject private var libraryHost = LibraryHost()

    /// App-wide error surfacing. Mounted at the root via ``View/toastHost(_:)``
    /// so every screen pushed onto the navigation stack inherits the toast
    /// banner / resumable sheet / catastrophic alert presentation without
    /// re-installing the modifier.
    @StateObject private var toastCenter = ToastCenter()

    /// App-wide preferences (haptic strength today; more in v0.5+). Owned
    /// at the root so every screen can read via `@EnvironmentObject`.
    /// `HapticEngine` reaches `AppSettings.shared` directly so haptic
    /// gating works from non-View contexts (gesture handlers).
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            LibraryHostView(host: libraryHost)
                .environmentObject(toastCenter)
                .environmentObject(settings)
                .toastHost(toastCenter)
        }
    }
}

/// Owns the lazy `ProjectLibrary` construction so `App` can stay declarative.
/// If `ProjectLibrary.init()` throws (App Support directory not creatable,
/// permission failure on first launch), we surface `setupError` instead of
/// hanging the UI.
@MainActor
final class LibraryHost: ObservableObject {
    @Published var library: ProjectLibrary?
    @Published var setupError: String?

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

    @ObservedObject var host: LibraryHost

    var body: some View {
        if let library = host.library {
            ProjectListView(library: library)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Couldn't open project library")
                    .font(.headline)
                if let message = host.setupError {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}
