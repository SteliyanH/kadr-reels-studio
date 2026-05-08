import Foundation
import CoreMedia
import Kadr

/// `splitClip` mutation — bisects the top-level clip with `id` at the playhead
/// (or any caller-provided composition time) and replaces it with the two
/// halves. Tier 1b carry of the v0.4 two-tier toolbar's `Split` action.
@MainActor
extension ProjectStore {

    /// Result of attempting a split. Surfaces failure modes the toolbar can
    /// show as a transient toast. Success carries no payload — the store has
    /// already mutated.
    enum SplitResult: Equatable {
        case ok
        case clipNotFound
        case clipInsideTrack          // Tracks aren't splittable in v0.4.
        case offsetOutOfRange         // Playhead at or beyond clip bounds.
        case unsupportedSpeedRate     // VideoClip with speedRate != 1.0.
    }

    /// Split the top-level clip with `id` at composition time `time`. No-op
    /// (returns the corresponding `SplitResult` case) when the clip can't be
    /// split — the toolbar surfaces these as transient toasts.
    @discardableResult
    func splitClip(id: ClipID, at time: CMTime) -> SplitResult {
        // 1. Locate top-level clip + its start time in the composition.
        guard let location = ProjectStore.topLevelLocation(for: id, in: project.clips) else {
            return project.clips.contains { Self.containsClipID(id, in: $0) }
                ? .clipInsideTrack
                : .clipNotFound
        }
        let offset = CMTimeSubtract(time, location.startTime)

        // 2. Split-at-boundary makes no sense; reject before touching state.
        let clip = project.clips[location.index]
        let bounds = CMTimeRange(start: .zero, duration: clip.duration)
        guard bounds.containsTime(offset),
              offset != .zero,
              offset != clip.duration
        else { return .offsetOutOfRange }

        // 3. Build halves.
        let halves: (any Clip, any Clip)?
        if let video = clip as? VideoClip {
            guard video.speedRate == 1.0 else { return .unsupportedSpeedRate }
            halves = ProjectStore.splitVideoClip(video, atRelativeTime: offset)
        } else if let image = clip as? ImageClip {
            halves = ProjectStore.splitImageClip(image, atRelativeTime: offset)
        } else if let title = clip as? TitleSequence {
            halves = ProjectStore.splitTitleSequence(title, atRelativeTime: offset)
        } else {
            return .clipInsideTrack  // Track / Transition fall here.
        }
        guard let (left, right) = halves else { return .offsetOutOfRange }

        // 4. Apply mutation.
        applyMutation("Split Clip") { project in
            project.clips.replaceSubrange(location.index...location.index, with: [left, right])
        }
        return .ok
    }

    // MARK: - Half builders

    nonisolated static func splitVideoClip(
        _ video: VideoClip,
        atRelativeTime offset: CMTime
    ) -> (any Clip, any Clip)? {
        // Source range — the slice of the underlying file the clip plays.
        // Without an explicit trim, that's [0, sourceDuration). With a trim,
        // we honor it. Composition-time and source-time match because we
        // already rejected speedRate != 1.0 at the call site.
        let source = video.trimRange
            ?? CMTimeRange(start: .zero, duration: video.duration)
        let leftRange = CMTimeRange(start: source.start, duration: offset)
        let rightRange = CMTimeRange(
            start: CMTimeAdd(source.start, offset),
            duration: CMTimeSubtract(source.duration, offset)
        )

        // Left keeps the original `clipID` so selection survives the cut on
        // the half closest to where the user typically clicked. Right gets a
        // fresh id so the two halves stay distinct mutations targets.
        let left = video.trimmed(to: leftRange)
        let right = video.trimmed(to: rightRange).id(ClipID(UUID().uuidString))
        return (left, right)
    }

    nonisolated static func splitImageClip(
        _ image: ImageClip,
        atRelativeTime offset: CMTime
    ) -> (any Clip, any Clip)? {
        let leftDuration = offset
        let rightDuration = CMTimeSubtract(image.duration, offset)
        let left = image.duration(leftDuration)
        let right = image
            .duration(rightDuration)
            .id(ClipID(UUID().uuidString))
        return (left, right)
    }

    nonisolated static func splitTitleSequence(
        _ title: TitleSequence,
        atRelativeTime offset: CMTime
    ) -> (any Clip, any Clip)? {
        // TitleSequence has no duration setter modifier; rebuild via the
        // public init that takes a CMTime duration. We preserve text /
        // style / background; clipID + transform / opacity flow through
        // the surviving modifiers.
        let leftDuration = offset
        let rightDuration = CMTimeSubtract(title.duration, offset)

        let left = TitleSequence(
            title.text,
            duration: leftDuration,
            style: title.style,
            background: title.backgroundColor
        )
        let right = TitleSequence(
            title.text,
            duration: rightDuration,
            style: title.style,
            background: title.backgroundColor
        )

        let leftRebuilt = ProjectStore.reapplyTitleModifiers(from: title, to: left, freshID: false)
        let rightRebuilt = ProjectStore.reapplyTitleModifiers(from: title, to: right, freshID: true)
        return (leftRebuilt, rightRebuilt)
    }

    nonisolated static func reapplyTitleModifiers(
        from source: TitleSequence,
        to target: TitleSequence,
        freshID: Bool
    ) -> TitleSequence {
        var out = target
        if let id = source.clipID, !freshID { out = out.id(id) }
        else if freshID { out = out.id(ClipID(UUID().uuidString)) }
        if let t = source.transform { out = out.transform(t) }
        if let o = source.opacity { out = out.opacity(o) }
        return out
    }

    // MARK: - Lookup helpers

    /// Index + composition start time of the top-level clip with `id`. `nil`
    /// when the clip isn't at the top level (may still exist inside a Track —
    /// `containsClipID(_:in:)` distinguishes).
    nonisolated static func topLevelLocation(
        for id: ClipID,
        in clips: [any Clip]
    ) -> (index: Int, startTime: CMTime)? {
        var cursor: CMTime = .zero
        for (i, clip) in clips.enumerated() {
            if clip.clipID == id { return (i, cursor) }
            cursor = CMTimeAdd(cursor, clip.duration)
        }
        return nil
    }

    /// Recursive containment check — true if `id` is anywhere in `clip`,
    /// including inside a `Track`. Used to distinguish "clip not found" from
    /// "clip is inside a Track" when reporting the failure mode.
    nonisolated static func containsClipID(_ id: ClipID, in clip: any Clip) -> Bool {
        if clip.clipID == id { return true }
        if let track = clip as? Track {
            return track.clips.contains { containsClipID(id, in: $0) }
        }
        return false
    }
}
