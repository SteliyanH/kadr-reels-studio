import Foundation
#if canImport(Photos)
import Photos
#endif
#if canImport(UIKit)
import UIKit
#endif

/// v0.6 Tier 4 — pre-check Photos library authorization before presenting
/// `PhotoPicker`. Pre-Tier 4 the picker was presented unconditionally; iOS
/// would silently show an empty / restricted picker when access was denied,
/// leaving the user stuck. Now we route `.denied` / `.restricted` to a
/// Settings.app redirect alert; `.notDetermined` triggers the system prompt;
/// `.authorized` / `.limited` fall through unchanged.
///
/// Stateless and `nonisolated` so call sites can `await` from any context.
public enum PhotosAuthorizationGate {

    public enum Decision: Sendable, Equatable {
        /// Permission is granted (full or limited). Caller can present the
        /// picker.
        case proceed
        /// User has affirmatively denied or restricted Photos access. Caller
        /// should show a Settings redirect prompt.
        case openSettings
        /// Photos framework unavailable on this platform. Treated as proceed
        /// so non-iOS targets keep building (macOS / Catalyst photos picker
        /// uses different APIs).
        case unavailable
    }

    /// Check current status and request access if needed. Returns the
    /// resulting decision; never throws (the Photos framework's request
    /// surface returns an enum, not an error). On platforms without Photos
    /// (e.g. macOS) returns ``Decision/unavailable``.
    public static func ensureAccess() async -> Decision {
        #if canImport(Photos)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return .proceed
        case .denied, .restricted:
            return .openSettings
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch granted {
            case .authorized, .limited: return .proceed
            case .denied, .restricted:  return .openSettings
            case .notDetermined:        return .openSettings
            @unknown default:           return .openSettings
            }
        @unknown default:
            return .openSettings
        }
        #else
        return .unavailable
        #endif
    }

    /// Open the system Settings app at this app's permissions screen so the
    /// user can flip Photos back on. No-op on platforms without UIKit.
    @MainActor
    public static func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
