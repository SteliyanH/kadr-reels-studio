import SwiftUI

/// How ``PreviewArea`` draws the stage's picture layer.
///
/// This exists for one reason: snapshot-test determinism (issue #75). The live
/// stage is an AVKit player — kadr-ui's `VideoPreview` builds an `AVPlayer`
/// inside a `.task` on first appear, so the frame a snapshot captures depends
/// on whether that asynchronous load has finished, failed, or not yet started.
/// With a placeholder fixture asset the failure path is asynchronous too, so a
/// baseline taken of the editor races between kadr-ui's loading spinner and its
/// failure glyph, and no baseline can be trusted.
///
/// ``StageRendering/placeholder`` removes the race at its source by not
/// constructing the player at all. Everything else on the stage — the letterbox
/// ground, the spec chip, the AVKit chrome blocker, the overlay host — is pure
/// SwiftUI over the project's own data, so a fixed store renders one fixed
/// frame.
///
/// **Never set in production.** The default is ``StageRendering/live``, and the
/// app never writes this key: the only call sites are in test targets. Every
/// production build therefore renders exactly as it did before the key existed.
enum StageRendering {

    /// The real stage: kadr-ui's `VideoPreview` loads and plays the
    /// composition. The default, and the only value the app itself ever uses.
    case live

    /// Test-only. The picture layer is replaced by the stage's own letterbox
    /// ground — no `AVPlayer`, no asynchronous load, no spinner-versus-glyph
    /// race. Carries no copy of its own, so it adds no user-facing strings.
    case placeholder
}

private struct StageRenderingKey: EnvironmentKey {
    static let defaultValue: StageRendering = .live
}

extension EnvironmentValues {
    /// How the stage's picture layer is drawn. Defaults to
    /// ``StageRendering/live``; only snapshot tests set it, and they set it on
    /// the view under test (`EditorView`, `PreviewArea`) so it flows down the
    /// environment to ``PreviewArea`` wherever the stage is composed:
    ///
    /// ```swift
    /// EditorView(store: store)
    ///     .environment(\.stageRendering, .placeholder)
    /// ```
    ///
    /// See ``StageRendering`` for why the seam exists (issue #75).
    var stageRendering: StageRendering {
        get { self[StageRenderingKey.self] }
        set { self[StageRenderingKey.self] = newValue }
    }
}
