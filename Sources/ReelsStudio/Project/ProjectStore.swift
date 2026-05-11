import Foundation
import Combine
import CoreMedia
import SwiftUI
import Kadr
import KadrUI

/// `ObservableObject` owning the editor's ``Project`` state. Targeting iOS 16 keeps
/// us on `ObservableObject` rather than the iOS 17+ `@Observable` macro — a v0.2
/// patch can swap when the deployment floor moves.
///
/// The store is the single source of truth. Mutations go through its methods so we
/// can extend them later (history / undo, persistence). The derived ``video`` is
/// recomputed on every read; SwiftUI's body invalidation handles caching at the
/// view level.
@MainActor
final class ProjectStore: ObservableObject {

    @Published private(set) var project: Project

    /// Currently-selected clip's ``ClipID``, mirrored to the inspector and keyframe
    /// editor. `nil` when nothing's selected.
    @Published var selectedClipID: ClipID? {
        didSet {
            // Mutual exclusion: selecting a clip clears any overlay selection.
            // The editor body picks which inspector / keyframe surface to
            // show based on which slot is non-nil.
            if selectedClipID != nil { selectedOverlayID = nil }
        }
    }

    /// Currently-selected overlay's ``LayerID``. v0.3 surfaces selection
    /// through the Layers sheet; v0.4 will add tap-to-select on
    /// ``KadrUI/OverlayHost``. Mutually exclusive with ``selectedClipID``.
    @Published var selectedOverlayID: LayerID? {
        didSet {
            if selectedOverlayID != nil { selectedClipID = nil }
        }
    }

    /// Composition-time playhead. Driven by `TimelineView`'s tap-to-scrub.
    @Published var currentTime: CMTime = .zero

    /// Multi-select mode flag — when `true`, taps on timeline clips toggle
    /// set membership (`selectedClipIDs`) instead of writing single-select
    /// (`selectedClipID`). Entered via long-press on a clip (kadr-ui v0.9.2's
    /// `onLongPressClip`); exited via the multi-select toolbar's Cancel or
    /// by completing a `wrapInTrack`. Clearing the flag clears the set.
    /// v0.4 Tier 5.
    @Published var isMultiSelecting: Bool = false {
        didSet {
            if !isMultiSelecting { selectedClipIDs.removeAll() }
        }
    }

    /// The set of clip ids currently multi-selected. Drives kadr-ui v0.9.2's
    /// `selectedClipIDs:` binding (every member of the set renders a
    /// selection ring). Empty when not in multi-select mode. v0.4 Tier 5.
    @Published var selectedClipIDs: Set<ClipID> = []

    /// History stack for ``undo()`` / ``redo()``. Snapshots the previous
    /// `Project` value before every mutation. Selection / playhead aren't
    /// part of the undo timeline — they're UX state, not document state.
    let undoManager = UndoManager()

    /// SwiftUI-observable mirror of ``undoManager.canUndo``. Drives the
    /// disabled state of the toolbar arrows.
    @Published private(set) var canUndo = false

    /// SwiftUI-observable mirror of ``undoManager.canRedo``.
    @Published private(set) var canRedo = false

    init(project: Project) {
        self.project = project
        // Disable auto-grouping so each mutation becomes its own undo step.
        // Without this, every mutation in the same runloop tick coalesces
        // into one big undo (e.g. three sequential `append(clip:)` calls
        // would undo together) — wrong UX for an editor where users
        // expect per-action granularity. Future tier could re-introduce
        // coalescing for *rapid* slider edits via a debounced
        // beginUndoGrouping/endUndoGrouping pair.
        undoManager.groupsByEvent = false
    }

    /// Convenience: build a fresh store with the bundled sample clips. Used
    /// by previews and detached test fixtures — production launches go
    /// through ``ProjectLibrary`` + ``EditorView(document:library:)``.
    static func sample() -> ProjectStore {
        ProjectStore(project: SampleProject.make())
    }

    /// Derived `Video` for previewing / exporting. Recomputed on every read.
    var video: Video {
        project.makeVideo()
    }

    // MARK: - History (snapshot-based undo / redo)

    /// Apply `mutation` to the project after capturing the previous value
    /// for undo. Every public mutation routes through here so the history
    /// stack stays complete. `actionName` shows up in the system "Undo X"
    /// menu on iPad / Mac (no-op on iPhone where the menu doesn't render).
    /// Internal so extensions in other files (e.g. `ProjectStore+Overlays`)
    /// can route their mutations through the same undo / save plumbing.
    func applyMutation(_ actionName: String, _ mutation: (inout Project) -> Void) {
        let previous = project
        var next = project
        mutation(&next)
        project = next
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { store in
            store.swapProject(to: previous, redoSnapshot: next, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        refreshUndoFlags()
    }

    /// Undo / redo's apply path. Captures the *current* project so redo
    /// can roll forward. Used by both `undo()` and the registerUndo
    /// callback above (which itself registers redo).
    private func swapProject(to target: Project, redoSnapshot: Project, actionName: String) {
        let beforeSwap = project
        project = target
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { store in
            store.swapProject(to: redoSnapshot, redoSnapshot: beforeSwap, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        refreshUndoFlags()
    }

    /// Sync the SwiftUI-observable flags with the underlying UndoManager.
    /// Called after every mutation / undo / redo.
    private func refreshUndoFlags() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }

    /// Roll back the most recent mutation. No-op if the history stack is
    /// empty (``undoManager.canUndo`` is false).
    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        refreshUndoFlags()
    }

    /// Re-apply a mutation that was just undone.
    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        refreshUndoFlags()
    }

    // MARK: - Mutations

    func append(clip: any Clip) {
        applyMutation("Add Clip") { $0.clips.append(clip) }
    }

    func append(clips newClips: [any Clip]) {
        let label = newClips.count == 1 ? "Add Clip" : "Add Clips"
        applyMutation(label) { $0.clips.append(contentsOf: newClips) }
    }

    func append(overlay: any Overlay) {
        applyMutation("Add Overlay") { $0.overlays.append(overlay) }
    }

    func append(audioTrack: AudioTrack) {
        applyMutation("Add Audio") { $0.audioTracks.append(audioTrack) }
    }

    func append(captions newCaptions: [Caption]) {
        applyMutation("Add Captions") { $0.captions.append(contentsOf: newCaptions) }
    }

    /// Replace the project's full caption list. Used by the v0.3 caption
    /// editor's `onUpdate` callback (it always emits the full sorted array,
    /// not a diff). Routed through `applyMutation` so undo/redo and
    /// auto-save Just Work.
    func setCaptions(_ newCaptions: [Caption]) {
        applyMutation("Edit Captions") { $0.captions = newCaptions }
    }

    func setPreset(_ preset: Preset) {
        applyMutation("Change Preset") { $0.preset = preset }
    }

    /// Update the persisted timeline zoom. **Does not** push an undo entry —
    /// zoom is viewport state that the user expects to persist across launches
    /// but not pollute the undo history (every pinch tick would otherwise
    /// flood the stack). Auto-save still observes `$project` and writes the
    /// new value to disk on the trailing debounce edge.
    func updateZoom(_ zoom: TimelineZoom?) {
        project.zoom = zoom
    }

    /// Set the per-project accent color. Routed through `applyMutation` so
    /// the user can undo a color choice (color is creative state — unlike
    /// zoom / fixed-center-playhead which are viewport preferences).
    /// v0.5 Tier 1.
    func setAccentColor(_ color: Color?) {
        applyMutation("Set Accent Color") { $0.accentColor = color }
    }

    /// Set the per-project fixed-center-playhead preference. Does **not**
    /// push undo — like `updateZoom`, this is viewport state the user
    /// expects to persist but not flood the undo stack. v0.5 Tier 1.
    func setFixedCenterPlayhead(_ enabled: Bool) {
        project.fixedCenterPlayhead = enabled
    }

    /// Apply a trim delta to a clip inside a `Track {}` block. `KadrUI`'s
    /// `onTrackTrim` callback hands us deltas, not the resulting clip, so
    /// we walk to the right inner clip and apply the appropriate trim
    /// modifier. Routed through `applyMutation` so undo / auto-save inherit.
    ///
    /// - Parameters:
    ///   - trackIndex: 0-based ordinal among Track-typed entries in
    ///     `project.clips`.
    ///   - clipIndex: 0-based position within the Track's `clips` array.
    ///   - leadingTrim / trailingTrim: signed deltas in seconds. Positive
    ///     trims; negative extends. See `KadrUI.TimelineView.onTrackTrim`'s
    ///     contract for the precise sign convention.
    func applyTrackTrim(
        trackIndex: Int,
        clipIndex: Int,
        leadingTrim: CMTime,
        trailingTrim: CMTime
    ) {
        applyMutation("Trim Clip") { project in
            project.clips = ProjectStore.applyingTrackTrim(
                clips: project.clips,
                trackIndex: trackIndex,
                clipIndex: clipIndex,
                leadingTrim: leadingTrim,
                trailingTrim: trailingTrim
            )
        }
    }

    /// Pure helper: produce a new clips array with the trim applied to the
    /// requested inner clip. Returns the array unchanged for out-of-range
    /// indices (matches editor-consumer expectations under stale indices).
    nonisolated static func applyingTrackTrim(
        clips: [any Clip],
        trackIndex: Int,
        clipIndex: Int,
        leadingTrim: CMTime,
        trailingTrim: CMTime
    ) -> [any Clip] {
        // Find the Track at the given track-only ordinal.
        var seen = 0
        var topLevelIndex: Int? = nil
        for (i, clip) in clips.enumerated() where clip is Track {
            if seen == trackIndex { topLevelIndex = i; break }
            seen += 1
        }
        guard let topLevelIndex,
              let track = clips[topLevelIndex] as? Track,
              clipIndex >= 0, clipIndex < track.clips.count else {
            return clips
        }
        let oldInner = track.clips[clipIndex]
        guard let newInner = ProjectStore.applyingTrim(
            to: oldInner,
            leadingTrim: leadingTrim,
            trailingTrim: trailingTrim
        ) else { return clips }
        var newInners = track.clips
        newInners[clipIndex] = newInner
        let rebuiltTrack = ProjectStore.rebuildTrack(track, clips: newInners)
        var newTopLevel = clips
        newTopLevel[topLevelIndex] = rebuiltTrack
        return newTopLevel
    }

    /// Apply trim deltas to a clip. For VideoClip, shift `trimRange` by the
    /// deltas; for ImageClip / TitleSequence, adjust `duration` by
    /// `-(leading + trailing)` (only the back handle moves since they have
    /// no source-asset front to retrieve). Returns nil for unsupported clip
    /// kinds.
    nonisolated static func applyingTrim(
        to clip: any Clip,
        leadingTrim: CMTime,
        trailingTrim: CMTime
    ) -> (any Clip)? {
        if let video = clip as? VideoClip {
            // Engine's trimRange semantics: positive leadingTrim trims the
            // front; positive trailingTrim trims the back.
            let oldRange = video.trimRange ?? CMTimeRange(start: .zero, duration: video.duration)
            let newStart = CMTimeAdd(oldRange.start, leadingTrim)
            let newEnd = CMTimeSubtract(CMTimeAdd(oldRange.start, oldRange.duration), trailingTrim)
            let newRange = CMTimeRange(start: newStart, duration: CMTimeSubtract(newEnd, newStart))
            return video.trimmed(to: newRange)
        }
        if let image = clip as? ImageClip {
            let totalTrim = CMTimeAdd(leadingTrim, trailingTrim)
            let newDuration = CMTimeSubtract(image.duration, totalTrim)
            guard CMTimeCompare(newDuration, .zero) > 0 else { return nil }
            var rebuilt = ImageClip(image.image, duration: newDuration)
            if let opacity = image.opacity { rebuilt = rebuilt.opacity(opacity) }
            if let id = image.clipID { rebuilt = rebuilt.id(id) }
            return rebuilt
        }
        if let title = clip as? TitleSequence {
            let totalTrim = CMTimeAdd(leadingTrim, trailingTrim)
            let newDuration = CMTimeSubtract(title.duration, totalTrim)
            guard CMTimeCompare(newDuration, .zero) > 0 else { return nil }
            var rebuilt = TitleSequence(
                title.text,
                duration: newDuration,
                style: title.style,
                background: title.backgroundColor
            )
            if let opacity = title.opacity { rebuilt = rebuilt.opacity(opacity) }
            if let id = title.clipID { rebuilt = rebuilt.id(id) }
            return rebuilt
        }
        // Transitions / Tracks aren't trimmed via this path.
        return nil
    }

    /// Rebuild a `Track` with new inner clips, preserving `startTime` /
    /// `name` / `opacityFactor`.
    nonisolated static func rebuildTrack(_ source: Track, clips: [any Clip]) -> Track {
        let start = source.startTime ?? .zero
        var rebuilt = Track(at: start, name: source.name) {
            for c in clips { c }
        }
        if source.opacityFactor != 1.0 {
            rebuilt = rebuilt.opacity(source.opacityFactor)
        }
        return rebuilt
    }

    /// Replace the speed curve on the identified `VideoClip`. Pass `nil` to
    /// clear the curve (the engine then uses the static `speedRate` instead;
    /// the user resets the rate via `clip.speed(1.0)` independently). No-op
    /// for non-VideoClip clip kinds.
    ///
    /// Routes through ``SpeedCurveEditor``'s `onUpdate` callback. Persists
    /// via the schema-v2 `VideoClipData.speedCurve` field, which already
    /// round-trips through the bridge and survives undo / redo.
    func applySpeedCurve(id: ClipID, _ curve: Kadr.Animation<Double>?) {
        updateClip(id: id, actionName: "Speed Curve") { clip in
            guard let video = clip as? VideoClip else { return clip }
            if let curve {
                return video.speed(curve: curve)
            }
            // Clear the curve — kadr's `speed(curve:)` doesn't have a nil
            // overload, so we fall back to setting a flat rate. The user's
            // existing speedRate (1.0 by default) restores; if they
            // previously had a non-1.0 rate, it stays.
            return video.speed(video.speedRate)
        }
    }

    /// Swap two top-level chain clips. The timeline's `onReorder` callback hands us
    /// the new array directly — we just replace.
    func replaceClips(_ newClips: [any Clip]) {
        applyMutation("Reorder Clips") { $0.clips = newClips }
    }

    /// Find the chain clip with the given `ClipID` and replace it with the result of
    /// `transform`. No-op if the ID isn't found. Used by the inspector to apply
    /// `Transform` / opacity / filter-intensity edits without rebuilding the
    /// entire clip array.
    func updateClip(id: ClipID, actionName: String = "Edit Clip", _ transform: (any Clip) -> any Clip) {
        let mapped = project.clips.map { clip in
            clip.clipID == id ? transform(clip) : clip
        }
        applyMutation(actionName) { $0.clips = mapped }
    }

    /// Apply a Transform to the selected clip (across `VideoClip` / `ImageClip` /
    /// `TitleSequence`).
    func applyTransform(id: ClipID, _ t: Transform) {
        updateClip(id: id, actionName: "Edit Transform") { clip in
            if let v = clip as? VideoClip { return v.transform(t) }
            if let i = clip as? ImageClip { return i.transform(t) }
            if let title = clip as? TitleSequence { return title.transform(t) }
            return clip
        }
    }

    /// Apply opacity (0...1) to the selected clip.
    func applyOpacity(id: ClipID, _ opacity: Double) {
        updateClip(id: id, actionName: "Edit Opacity") { clip in
            if let v = clip as? VideoClip { return v.opacity(opacity) }
            if let i = clip as? ImageClip { return i.opacity(opacity) }
            if let title = clip as? TitleSequence { return title.opacity(opacity) }
            return clip
        }
    }

    /// Replace the scalar of `VideoClip.filters[index]` and rebuild the clip with
    /// the new filter list. No-op when the clip isn't a `VideoClip` or the index is
    /// out of range. Mirrors kadr's internal `Filter.withScalar(_:)` (which isn't
    /// publicly accessible as of kadr 0.9.2; revisit if it becomes public).
    func applyFilterIntensity(id: ClipID, filterIndex: Int, value: Double) {
        updateClip(id: id, actionName: "Edit Filter") { clip in
            guard let video = clip as? VideoClip else { return clip }
            guard filterIndex >= 0, filterIndex < video.filters.count else { return clip }
            var rebuilt = VideoClip(url: video.url)
            if let trim = video.trimRange { rebuilt = rebuilt.trimmed(to: trim) }
            for (i, filter) in video.filters.enumerated() {
                let updated = (i == filterIndex)
                    ? Self.filter(filter, withScalar: value)
                    : filter
                rebuilt = rebuilt.filter(updated)
            }
            if let id = video.clipID { rebuilt = rebuilt.id(id) }
            if let t = video.transform { rebuilt = rebuilt.transform(t) }
            if let o = video.opacity { rebuilt = rebuilt.opacity(o) }
            return rebuilt
        }
    }

    /// Build a new `Filter` case substituting `scalar` for the primary numeric
    /// parameter. Mirrors kadr's internal `Filter.withScalar(_:)`. Filters without a
    /// scalar parameter return unchanged.
    private static func filter(_ filter: Filter, withScalar scalar: Double) -> Filter {
        switch filter {
        case .brightness:   return .brightness(scalar)
        case .contrast:     return .contrast(scalar)
        case .saturation:   return .saturation(scalar)
        case .exposure:     return .exposure(scalar)
        case .sepia:        return .sepia(intensity: scalar)
        case .gaussianBlur: return .gaussianBlur(radius: scalar)
        case .vignette:     return .vignette(intensity: scalar)
        case .sharpen:      return .sharpen(amount: scalar)
        case .zoomBlur:     return .zoomBlur(amount: scalar)
        case .glow:         return .glow(intensity: scalar)
        case .mono, .lut, .chromaKey: return filter
        }
    }
}
