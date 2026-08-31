import Foundation
import KadrPersistence
import CoreMedia
import SwiftUI
import Kadr
import KadrUI

/// `@Observable` store owning the editor's ``Project`` state. Migrated from
/// `ObservableObject` when the deployment floor moved to iOS 17.
///
/// The store is the single source of truth. Mutations go through its methods so we
/// can extend them later (history / undo, persistence). The derived ``video`` is
/// recomputed on every read; SwiftUI's body invalidation handles caching at the
/// view level.
@MainActor
@Observable
final class ProjectStore {

    private(set) var project: Project {
        didSet { revision &+= 1 }
    }

    /// Monotonic change counter — bumped on every `project` mutation. A stable,
    /// `Equatable` signal for `onChange`-driven auto-save now that `@Observable`
    /// replaced the `@Published` Combine publisher the debounce used to observe.
    /// `Project` itself isn't `Equatable` (it holds `[any Clip]` existentials).
    private(set) var revision = 0

    /// Currently-selected clip's ``ClipID``, mirrored to the inspector and keyframe
    /// editor. `nil` when nothing's selected.
    var selectedClipID: ClipID? {
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
    var selectedOverlayID: LayerID? {
        didSet {
            if selectedOverlayID != nil { selectedClipID = nil }
        }
    }

    /// Composition-time playhead. Driven by `TimelineView`'s tap-to-scrub, and
    /// from v0.9 by the transport band and by playback itself — kadr-ui's
    /// periodic observer pushes the player's position back in here roughly ten
    /// times a second while ``isPlaying``.
    var currentTime: CMTime = .zero

    /// v0.9 — whether the stage is playing.
    ///
    /// Two-way with `VideoPreview(isPlaying:)`: writing it starts or stops the
    /// player, and the player writes back — a non-looping composition running
    /// out clears it, so the transport's play button can't sit stuck showing
    /// "pause". Session UX state, the same kind as ``currentTime`` and the
    /// selection slots above: not part of the document, not part of the undo
    /// timeline, not persisted.
    var isPlaying: Bool = false

    /// v0.9 — whether playback restarts at zero when it reaches the end.
    ///
    /// **The app owns this, not `VideoPreview(loops:)`.** kadr-ui 0.14 reads
    /// `loops` while it builds the player, inside `.task(id: identity)`, and
    /// `identity` is a fingerprint over clip / overlay / audio counts and
    /// duration — `loops` is not in it. The periodic observer's closure
    /// captures the value from construction time, so toggling this flag would
    /// have no effect until something else rebuilt the player: a loop button
    /// that reads correctly and is inert on device. ``PreviewArea`` therefore
    /// always passes `loops: false` and ``ReelTransportBand`` performs the restart
    /// itself.
    ///
    /// Resets per session — no `@SceneStorage`, no schema field. Loop is a
    /// mode you switch on while working, not a property of the project.
    var isLooping: Bool = false

    /// Multi-select mode flag — when `true`, taps on timeline clips toggle
    /// set membership (`selectedClipIDs`) instead of writing single-select
    /// (`selectedClipID`). Entered via long-press on a clip (kadr-ui v0.9.2's
    /// `onLongPressClip`); exited via the multi-select toolbar's Cancel or
    /// by completing a `wrapInTrack`. Clearing the flag clears the set.
    /// v0.4 Tier 5.
    var isMultiSelecting: Bool = false {
        didSet {
            if !isMultiSelecting { selectedClipIDs.removeAll() }
        }
    }

    /// The set of clip ids currently multi-selected. Drives kadr-ui v0.9.2's
    /// `selectedClipIDs:` binding (every member of the set renders a
    /// selection ring). Empty when not in multi-select mode. v0.4 Tier 5.
    var selectedClipIDs: Set<ClipID> = []

    /// History stack for ``undo()`` / ``redo()``. Snapshots the previous
    /// `Project` value before every mutation. Selection / playhead aren't
    /// part of the undo timeline — they're UX state, not document state.
    let undoManager = UndoManager()

    /// SwiftUI-observable mirror of ``undoManager.canUndo``. Drives the
    /// disabled state of the toolbar arrows.
    private(set) var canUndo = false

    /// SwiftUI-observable mirror of ``undoManager.canRedo``.
    private(set) var canRedo = false

    /// How this session names its images.
    ///
    /// Session-scoped on purpose. An `ImageClip` holds decoded pixels with no
    /// record of where they came from, so the mapping from image to origin is
    /// the app's to keep — and it has to survive from the moment a photo is
    /// imported until the moment the project is saved. A store created fresh at
    /// save time would have forgotten every URL and re-embedded whole photos as
    /// bytes.
    let images: ProjectImageStore

    init(project: Project, images: ProjectImageStore = ProjectImageStore.temporary()) {
        self.project = project
        self.images = images
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

    // MARK: - Transitions (v0.7 Tier 2)

    /// Insert a `Transition` after the clip with `afterClipID`, or *replace*
    /// the existing transition at that gap if one is already there. No-op
    /// when the clip is the last one in `project.clips` (a transition needs
    /// a successor to dissolve into).
    ///
    /// Mutation routes through `applyMutation` so undo / auto-save inherit.
    /// Action name distinguishes the insert vs. replace case so the system
    /// Edit menu reads cleanly ("Add Transition" / "Change Transition").
    ///
    /// `kind` mirrors kadr's `Transition` enum cases at the API level — the
    /// `TransitionKind` enum here is a UI-friendly mirror that decouples the
    /// transitions picker sheet from kadr's type. v0.7 Tier 2.
    func insertTransition(
        afterClipID: ClipID,
        kind: TransitionKind,
        duration: CMTime
    ) {
        // Pre-compute whether we're replacing or inserting so applyMutation
        // gets the right action name. The pure helper does the work twice
        // when called inside the mutation closure (once for the name lookup,
        // once for the apply); cheap enough on a clips array to not matter.
        let replacing = ProjectStore.hasTransitionAfter(
            clipID: afterClipID,
            in: project.clips
        )
        let actionName = replacing ? "Change Transition" : "Add Transition"
        applyMutation(actionName) { project in
            project.clips = ProjectStore.insertingTransition(
                clips: project.clips,
                afterClipID: afterClipID,
                kind: kind,
                duration: duration
            )
        }
    }

    /// Pure helper: produce a new clips array with the transition either
    /// inserted or replaced. No-op (returns the array unchanged) when:
    /// - the clip with `afterClipID` isn't at the top level of `clips`, or
    /// - the clip is the last entry (a transition needs a successor).
    nonisolated static func insertingTransition(
        clips: [any Clip],
        afterClipID: ClipID,
        kind: TransitionKind,
        duration: CMTime
    ) -> [any Clip] {
        guard let index = clips.firstIndex(where: { $0.clipID == afterClipID }) else {
            return clips
        }
        let nextIndex = index + 1
        guard nextIndex < clips.count else { return clips }

        let transition: any Clip = kind.makeTransition(duration: duration)
        var newClips = clips
        if newClips[nextIndex] is Kadr.Transition {
            // Replace the existing transition at the gap.
            newClips[nextIndex] = transition
        } else {
            // Insert before the successor media clip.
            newClips.insert(transition, at: nextIndex)
        }
        return newClips
    }

    /// Pure helper: whether the clip with `clipID` is immediately followed by
    /// a transition in `clips`. Returns false when the clip isn't found or
    /// has no successor. Used by `insertTransition` to pick a clean action
    /// name for the system Edit menu, and by the UI to seed the transitions
    /// picker with the current selection.
    nonisolated static func hasTransitionAfter(
        clipID: ClipID,
        in clips: [any Clip]
    ) -> Bool {
        guard let index = clips.firstIndex(where: { $0.clipID == clipID }) else {
            return false
        }
        let nextIndex = index + 1
        return nextIndex < clips.count && clips[nextIndex] is Kadr.Transition
    }

    /// Remove the transition (if any) at the gap following `afterClipID`.
    /// No-op when no transition is present, so callers can issue
    /// unconditionally. v0.7 Tier 2.
    func removeTransition(afterClipID: ClipID) {
        applyMutation("Remove Transition") { project in
            project.clips = ProjectStore.removingTransition(
                clips: project.clips,
                afterClipID: afterClipID
            )
        }
    }

    /// Pure helper: produce a new clips array with the transition at the gap
    /// following `afterClipID` removed. Returns the array unchanged when no
    /// transition is in place.
    nonisolated static func removingTransition(
        clips: [any Clip],
        afterClipID id: ClipID
    ) -> [any Clip] {
        guard let index = clips.firstIndex(where: { $0.clipID == id }) else {
            return clips
        }
        let nextIndex = index + 1
        guard nextIndex < clips.count, clips[nextIndex] is Kadr.Transition else {
            return clips
        }
        var newClips = clips
        newClips.remove(at: nextIndex)
        return newClips
    }

    /// Pure helper: return the existing transition's kind + duration at the
    /// gap following the clip identified by `afterClipID`, if any. Powers
    /// the transitions picker's "seed current selection" behavior. Returns
    /// nil when no transition is in place.
    nonisolated static func currentTransition(
        afterClipID id: ClipID,
        in clips: [any Clip]
    ) -> (kind: TransitionKind, duration: CMTime)? {
        guard let index = clips.firstIndex(where: { $0.clipID == id }) else {
            return nil
        }
        let nextIndex = index + 1
        guard nextIndex < clips.count,
              let transition = clips[nextIndex] as? Kadr.Transition else {
            return nil
        }
        switch transition {
        case .fade(let dur):     return (.fade, dur)
        case .dissolve(let dur): return (.dissolve, dur)
        case .slide:
            // kadr v0.7 added `.slide` to the engine but the persistence
            // schema + reels-studio's `TransitionKind` mirror only know
            // fade + dissolve. Treat slide as "unknown to the picker" —
            // the sheet falls back to the default selection rather than
            // crashing on an exhaustiveness mismatch.
            return nil
        }
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

    /// Apply a leading + trailing trim delta to the audio track at
    /// `trackIndex` in `project.audioTracks`. v0.7 Tier 1 — wired from
    /// `kadr-ui v0.10.2`'s `TimelineView.onAudioTrim(_:)` callback.
    ///
    /// Music and SFX live in the same `audioTracks` array (only the
    /// `.at(time:)` modifier distinguishes them at the call site), so a
    /// single mutation handles both — `AddMusicSheet` and `AddSFXSheet`
    /// share the storage. Action name stays generic ("Trim Audio") so the
    /// Edit menu reads cleanly regardless of source.
    ///
    /// Sign convention mirrors `applyTrackTrim`:
    /// - `leadingTrim > 0` shifts `startTime` later (trims the head).
    /// - `trailingTrim > 0` reduces `explicitDuration` (trims the tail).
    /// - Negative deltas extend in the opposite direction; clamped to zero
    ///   so a runaway drag can't produce a negative duration.
    ///
    /// `explicitDuration == nil` means "play to natural asset end" — kadr-ui
    /// doesn't synchronously resolve the asset length, so a trailing trim on
    /// an unset duration is a no-op (the leading-trim startTime shift still
    /// applies). Once the user trims a trailing handle on such a track, the
    /// downstream music sheet's "Add" path can be re-entered to set an
    /// explicit duration explicitly. Acceptable for v0.7; revisit if real
    /// users hit it.
    func applyAudioTrim(
        trackIndex: Int,
        leadingTrim: CMTime,
        trailingTrim: CMTime
    ) {
        applyMutation("Trim Audio") { project in
            project.audioTracks = ProjectStore.applyingAudioTrim(
                tracks: project.audioTracks,
                trackIndex: trackIndex,
                leadingTrim: leadingTrim,
                trailingTrim: trailingTrim
            )
        }
    }

    /// Pure helper: produce a new audio-track array with the trim applied to
    /// the row at `trackIndex`. Returns the array unchanged for out-of-range
    /// indices (matches editor-consumer expectations under stale indices —
    /// same convention as `applyingTrackTrim`).
    nonisolated static func applyingAudioTrim(
        tracks: [AudioTrack],
        trackIndex: Int,
        leadingTrim: CMTime,
        trailingTrim: CMTime
    ) -> [AudioTrack] {
        guard tracks.indices.contains(trackIndex) else { return tracks }
        let existing = tracks[trackIndex]

        // Shift startTime by the leading delta. Clamp to .zero so a runaway
        // drag can't push the track to negative composition time.
        let baseStart = existing.startTime ?? .zero
        let newStart = CMTimeMaximum(.zero, baseStart + leadingTrim)
        var track = existing.at(time: newStart)

        // Trim trailing only when explicitDuration is set — without it we
        // don't know the natural asset length synchronously. Same caveat is
        // surfaced by the upstream kadr-ui Tier 1 callback contract.
        if let existingDuration = existing.explicitDuration {
            let newDuration = CMTimeMaximum(
                .zero,
                existingDuration - leadingTrim - trailingTrim
            )
            track = track.duration(newDuration)
        }

        var copy = tracks
        copy[trackIndex] = track
        return copy
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
    /// the user resets the rate via `clip.speed(.flat(1.0))` independently). No-op
    /// for non-VideoClip clip kinds.
    ///
    /// Routes through ``SpeedCurveEditor``'s `onUpdate` callback. Persists
    /// via the schema-v2 `VideoClipData.speedCurve` field, which already
    /// round-trips through the bridge and survives undo / redo.
    func applySpeedCurve(id: ClipID, _ curve: Kadr.Animation<Double>?) {
        updateClip(id: id, actionName: "Speed Curve") { clip in
            guard let video = clip as? VideoClip else { return clip }
            // v0.6 — migrate to kadr v0.11's Speed enum. The enum makes
            // flat/curved exclusivity structural; falling back to
            // .flat(speedRate) preserves the v0.5 semantic where clearing
            // the curve restored the user's prior flat rate.
            if let curve {
                return video.speed(.curved(curve))
            }
            return video.speed(.flat(video.speedRate))
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
    /// Update the scalar parameter of `filters[filterIndex]` on the selected
    /// `VideoClip`. No-op when the clip isn't a `VideoClip` or the index is
    /// out of range.
    ///
    /// v0.6 — migrated to kadr v0.11's `setFilter(for:_:)` keyed API +
    /// the now-public `Filter.withScalar(_:)`. Pre-v0.6 we rebuilt the clip
    /// from scratch via `VideoClip(url:)` + walking every filter + re-
    /// applying every modifier, which re-issued every `FilterID` and
    /// orphaned any bound animation. The keyed surface preserves the slot's
    /// id and its bound animation atomically.
    func applyFilterIntensity(id: ClipID, filterIndex: Int, value: Double) {
        updateClip(id: id, actionName: "Edit Filter") { clip in
            guard let video = clip as? VideoClip else { return clip }
            guard filterIndex >= 0, filterIndex < video.filterIDs.count else { return clip }
            let filterID = video.filterIDs[filterIndex]
            let scaled = video.filters[filterIndex].withScalar(value)
            return video.setFilter(for: filterID, scaled)
        }
    }

    // v0.6 — local `filter(_:withScalar:)` mirror dropped. kadr v0.10 made
    // `Filter.withScalar(_:)` public; we call it directly in
    // `applyFilterIntensity` above.
}
