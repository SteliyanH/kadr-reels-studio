import XCTest
import SwiftUI
@testable import ReelsStudio

/// Issue #75 — the one invariant the stage seam's safety rests on.
///
/// ``StageRendering`` exists purely so snapshot tests can swap kadr-ui's
/// asynchronous `VideoPreview` for a static letterbox field. The claim that
/// makes that acceptable is that production is byte-for-byte unaffected:
/// the environment key defaults to ``StageRendering/live`` and nothing in the
/// app ever writes it, so ``PreviewArea`` always takes the real-player branch.
///
/// **Why this file exists.** Until now that invariant was asserted only by a
/// doc comment. If the default ever flipped to ``StageRendering/placeholder``
/// — a one-token edit in `StageRendering.swift`, or an accidental
/// `.environment(\.stageRendering, .placeholder)` left on a production view —
/// the shipping editor would render a black rectangle where the player should
/// be, and *no other test in this repo would notice*: the snapshot suite skips
/// off CI and deliberately sets `.placeholder` itself, and every behavioural
/// test drives the store, not the picture layer. This makes the claim
/// self-verifying.
///
/// It lives outside `SnapshotTests.swift` on purpose. Every test in that file
/// opens with `requireCIPinnedRuntime()` and is therefore skipped on any
/// machine that is not CI's pinned runtime — which is exactly where this
/// assertion would be useless. This one must run on every single test pass.
final class StageRenderingTests: XCTestCase {

    /// A freshly defaulted `EnvironmentValues` — the state every production
    /// view hierarchy starts from, since the app never writes the key —
    /// resolves `\.stageRendering` to ``StageRendering/live``.
    ///
    /// Matched with a `switch` rather than `XCTAssertEqual` so that
    /// ``StageRendering`` needs no `Equatable` conformance it would otherwise
    /// have no use for, and so that adding a third case breaks this file's
    /// compilation — forcing whoever adds it to state which value production
    /// gets.
    func testStageRenderingDefaultsToLive() {
        switch EnvironmentValues().stageRendering {
        case .live:
            break
        case .placeholder:
            XCTFail(
                "\\.stageRendering defaulted to .placeholder. Production " +
                "PreviewArea would render the test letterbox instead of " +
                "kadr-ui's VideoPreview — the shipping editor would have no " +
                "picture. Restore StageRenderingKey.defaultValue to .live."
            )
        }
    }
}
