import AVFoundation
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
    /// The Track starts where the first wrapped clip started, so the wrapped
    /// clips keep their place in time. kadr draws a Track over the main
    /// chain, so a Track anchored anywhere else would cover the wrong part
    /// of the video. Async because an untrimmed `VideoClip` only knows its
    /// duration once its asset loads.
    ///
    /// On `.ok`, multi-select state is cleared and `selectedClipID` is set
    /// to the new Track's `clipID` (well — Tracks don't have a `clipID`, so
    /// selection clears entirely). Undo restores the pre-wrap clip array
    /// in one step.
    @discardableResult
    func wrapInTrack(ids: Set<ClipID>) async -> WrapInTrackResult {
        let range: ClosedRange<Int>
        switch wrapPlan(ids: ids) {
        case .wrap(let r): range = r
        case .reject(let reason): return reason
        }

        let revisionBefore = revision
        let start = await Self.timelineStart(ofClipAt: range.lowerBound, in: project.clips)
        // The project changed while durations loaded, so `range` and `start`
        // may describe clips that moved. Start over against the new state.
        guard revision == revisionBefore else { return await wrapInTrack(ids: ids) }

        let inner = Array(project.clips[range])
        let track = Track(at: start) {
            for c in inner { c }
        }
        applyMutation("Wrap in Track") { project in
            project.clips.replaceSubrange(range, with: [track])
        }

        // The Track has no clipID, so the inspector can't select it from
        // the toolbar; that's fine — the user sees the new lane and can tap
        // a clip inside it.
        isMultiSelecting = false
        selectedClipID = nil

        return .ok
    }

    private enum WrapPlan {
        case wrap(ClosedRange<Int>)
        case reject(WrapInTrackResult)
    }

    /// The top-level index range the wrap replaces, or why it can't.
    private func wrapPlan(ids: Set<ClipID>) -> WrapPlan {
        guard !ids.isEmpty else { return .reject(.noSelection) }

        // An id present in the set but missing from the top level (e.g.
        // already inside a Track) bails the whole mutation —
        // clipsNotAtTopLevel surfaces that to the user rather than silently
        // dropping clips.
        var indices: [Int] = []
        for id in ids {
            guard let i = project.clips.firstIndex(where: { $0.clipID == id }) else {
                return .reject(.clipsNotAtTopLevel)
            }
            indices.append(i)
        }
        indices.sort()
        guard let lo = indices.first, let hi = indices.last else { return .reject(.noSelection) }

        // Every clip in [lo...hi] must either be one of the selected ones OR
        // a clip without a clipID. A Transition is fine (it rides with the
        // clips around it); a Track can't appear, since any inner id would
        // already have failed the top-level check above.
        for i in lo...hi {
            if let id = project.clips[i].clipID, !ids.contains(id) {
                return .reject(.nonContiguous)
            }
        }
        return .wrap(lo...hi)
    }

    /// Where the clip at `index` starts in the composition, the way kadr's
    /// engine places it.
    ///
    /// A clip with an explicit start time starts there. A chained clip starts
    /// after every chained clip before it, pulled back by the overlap of each
    /// transition in between: a dissolve or slide overlaps its neighbours by
    /// its duration, a fade doesn't overlap. Tracks and clips with explicit
    /// start times sit outside the chain and don't move it.
    nonisolated static func timelineStart(ofClipAt index: Int, in clips: [any Clip]) async -> CMTime {
        if let explicit = clips[index].startTime { return explicit }
        var cursor = CMTime.zero
        for clip in clips[..<index] {
            if clip is Track || clip.startTime != nil { continue }
            if let transition = clip as? Transition {
                cursor = CMTimeSubtract(cursor, overlap(of: transition))
            } else {
                cursor = CMTimeAdd(cursor, await placedDuration(of: clip))
            }
        }
        return CMTimeMaximum(cursor, .zero)
    }

    private nonisolated static func overlap(of transition: Transition) -> CMTime {
        switch transition {
        case .fade: return .zero
        case .dissolve(let d), .slide(_, let d): return d
        }
    }

    /// A clip's duration on the timeline. An untrimmed `VideoClip` reports
    /// zero until its asset loads, so load it and apply the clip's speed
    /// through the same `duration` kadr uses for trimmed clips.
    private nonisolated static func placedDuration(of clip: any Clip) async -> CMTime {
        guard let video = clip as? VideoClip, video.trimRange == nil,
              let assetDuration = try? await video.metadata.duration else {
            return clip.duration
        }
        return video.trimmed(to: CMTimeRange(start: .zero, duration: assetDuration)).duration
    }
}
