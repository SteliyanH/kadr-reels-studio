import Foundation
import CoreMedia
import Kadr
import KadrUI

/// `splitClip` mutation — bisects the top-level clip with `id` at the playhead
/// (or any caller-provided composition time) and replaces it with the two
/// halves.
///
/// **The arithmetic lives in KadrUI now.** This file used to carry ~150 lines
/// of it: locating the clip, converting composition time to source time,
/// rebuilding each half, and reapplying every modifier by hand. All of that is
/// `KadrUI.ClipSplitter` as of kadr-ui 0.19, tested there against cases this
/// app never exercised — and its version fixes a bug this one had, where
/// splitting an animated `TitleSequence` silently dropped both keyframe tracks
/// and the clip's start time, because the rebuild reapplied only `transform`
/// and `opacity`.
///
/// What stays here is what is genuinely the app's: the undo grouping, the
/// toast-shaped result type, and the mutation itself.
@MainActor
extension ProjectStore {

    /// Result of attempting a split. Surfaces failure modes the toolbar can
    /// show as a transient toast. Success carries no payload — the store has
    /// already mutated.
    enum SplitResult: Equatable {
        case ok
        case clipNotFound
        case clipInsideTrack          // Tracks aren't splittable.
        case offsetOutOfRange         // Playhead at or beyond clip bounds.
        case unsupportedSpeedRate     // VideoClip with speedRate != 1.0.

        /// Map a splitter refusal onto the app's toast vocabulary.
        ///
        /// `notSplittable` — a transition — folds into `clipInsideTrack`
        /// because both mean "this isn't a thing you can cut", and the toolbar
        /// has always shown one message for them.
        init(_ failure: ClipSplitter.Failure) {
            switch failure {
            case .clipNotFound:         self = .clipNotFound
            case .clipInsideTrack:      self = .clipInsideTrack
            case .notSplittable:        self = .clipInsideTrack
            case .timeOutOfRange:       self = .offsetOutOfRange
            case .unsupportedSpeedRate: self = .unsupportedSpeedRate
            }
        }
    }

    /// Split the top-level clip with `id` at composition time `time`. No-op
    /// (returning the corresponding `SplitResult` case) when the clip can't be
    /// split — the toolbar surfaces these as transient toasts.
    @discardableResult
    func splitClip(id: ClipID, at time: CMTime) -> SplitResult {
        switch ClipSplitter.split(clips: project.clips, id: id, at: time) {
        case .success(let clips):
            applyMutation("Split Clip") { project in
                project.clips = clips
            }
            return .ok
        case .failure(let reason):
            return SplitResult(reason)
        }
    }
}
