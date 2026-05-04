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

    var body: some Scene {
        WindowGroup {
            LibraryHostView(host: libraryHost)
                .environmentObject(toastCenter)
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
        do {
            self.library = try ProjectLibrary()
        } catch {
            self.setupError = error.localizedDescription
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
