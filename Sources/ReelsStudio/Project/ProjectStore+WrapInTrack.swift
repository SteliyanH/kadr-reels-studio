import Foundation
import Kadr

/// `wrapInTrack` mutation — replaces a contiguous range of top-level clips
/// with a single `Track { ... }` block containing those clips. v0.4 Tier 5
/// of the two-tier toolbar's multi-select flow.
@MainActor
extension ProjectStore {

    /// Result of attempting a wrap. Surfaces failure modes the toolbar
    /// turns into transient toasts. Success carries no payload — the store
    /// has already mutated and exited multi-select mode.
    enum WrapInTrackResult: Equatable {
        case ok
        case noSelection
        case nonContiguous
        case clipsNotAtTopLevel
    }

    /// Wrap the clips with the given `ids` in a single `Track`. The
    /// selection must form a **contiguous** range at the top level —
    /// transitions between the selected clips travel into the Track with
    /// them (transitions don't carry a `clipID`, so they're picked up
    /// automatically when we walk `[minIndex...maxIndex]`). Non-contiguous
    /// selections are rejected so we don't silently reorder the chain.
    ///
    /// On `.ok`, multi-select state is cleared and `selectedClipID` is set
    /// to the new Track's `clipID` (well — Tracks don't have a `clipID`, so
    /// selection clears entirely). Undo restores the pre-wrap clip array
    /// in one step.
    @discardableResult
    func wrapInTrack(ids: Set<ClipID>) -> WrapInTrackResult {
        guard !ids.isEmpty else { return .noSelection }

        // 1. Locate each id's top-level index. An id present in the set but
        //    missing from the top level (e.g. already inside a Track) bails
        //    the whole mutation — clipsNotAtTopLevel surfaces that to the
        //    user rather than silently dropping clips.
        var indices: [Int] = []
        for id in ids {
            guard let i = project.clips.firstIndex(where: { $0.clipID == id }) else {
                return .clipsNotAtTopLevel
            }
            indices.append(i)
        }
        indices.sort()
        guard let lo = indices.first, let hi = indices.last else { return .noSelection }

        // 2. Contiguous check — every clip in [lo...hi] must either be one
        //    of the selected ones OR a transition (transitions ride with
        //    the preceding clip when chained, so they belong in the wrap).
        for i in lo...hi {
            let clip = project.clips[i]
            if let id = clip.clipID, !ids.contains(id) {
                return .nonContiguous
            }
            // Clips without clipID (Track, Transition) pass through — Track
            // shouldn't appear (it'd already have triggered the not-at-top-
            // level check above for any inner id), Transition is fine.
        }

        // 3. Build the Track + apply.
        let inner = Array(project.clips[lo...hi])
        let track = Track {
            for c in inner { c }
        }
        applyMutation("Wrap in Track") { project in
            project.clips.replaceSubrange(lo...hi, with: [track])
        }

        // 4. Exit multi-select. The Track has no clipID, so the inspector
        //    can't select it from the toolbar; that's fine — the user
        //    sees the new lane and can tap a clip inside it.
        isMultiSelecting = false
        selectedClipID = nil

        return .ok
    }
}
