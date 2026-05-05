import Foundation
import Kadr

/// Toolbar-driven mutations for the v0.4 two-tier toolbar — duplicate / delete /
/// reorder for clips and overlays. Split + filters wiring lands in v0.4 Tier 1b.
@MainActor
extension ProjectStore {

    // MARK: - Clip actions

    /// Remove the top-level clip with `id`. No-op if the clip isn't found at the
    /// top level (Track-contained clips aren't deletable from the toolbar in
    /// v0.4 — the Track is the unit; future tier may surface a per-Track row).
    func removeClip(id: ClipID) {
        guard project.clips.contains(where: { $0.clipID == id }) else { return }
        applyMutation("Delete Clip") { project in
            project.clips.removeAll { $0.clipID == id }
        }
        if selectedClipID == id { selectedClipID = nil }
    }

    /// Insert a duplicate of the clip with `id` immediately after the original.
    /// The duplicate gets a fresh `ClipID` so future edits don't ambiguate.
    /// No-op for Track / Transition (no `clipID`) and for ids not at the top
    /// level.
    func duplicateClip(id: ClipID) {
        guard let index = project.clips.firstIndex(where: { $0.clipID == id }),
              let copy = ProjectStore.cloneClipWithFreshID(project.clips[index])
        else { return }
        applyMutation("Duplicate Clip") { project in
            project.clips.insert(copy, at: index + 1)
        }
    }

    /// Returns a clone of `clip` with a freshly-generated `ClipID`. `nil` for
    /// types that don't carry an id (Track / Transition). Concrete-type
    /// dispatch keeps this nonisolated so it's callable from undo replays.
    nonisolated static func cloneClipWithFreshID(_ clip: any Clip) -> (any Clip)? {
        let newID = ClipID(UUID().uuidString)
        if let v = clip as? VideoClip { return v.id(newID) }
        if let i = clip as? ImageClip { return i.id(newID) }
        if let t = clip as? TitleSequence { return t.id(newID) }
        return nil
    }

    // MARK: - Overlay actions

    /// Remove the overlay with `id`. No-op if not found.
    func removeOverlay(id: LayerID) {
        guard project.overlays.contains(where: { $0.layerID == id }) else { return }
        applyMutation("Delete Overlay") { project in
            project.overlays.removeAll { $0.layerID == id }
        }
        if selectedOverlayID == id { selectedOverlayID = nil }
    }

    /// Insert a duplicate of the overlay with `id` immediately after the
    /// original (one z-step above). Duplicate gets a fresh `LayerID`.
    func duplicateOverlay(id: LayerID) {
        guard let index = project.overlays.firstIndex(where: { $0.layerID == id }),
              let copy = ProjectStore.cloneOverlayWithFreshID(project.overlays[index])
        else { return }
        applyMutation("Duplicate Overlay") { project in
            project.overlays.insert(copy, at: index + 1)
        }
    }

    /// Shift the overlay with `id` `delta` positions in the z-order array.
    /// Positive delta = bring forward (later draw), negative = send back.
    /// Clamps to array bounds; no-op when the move would be a no-op.
    func moveOverlay(id: LayerID, by delta: Int) {
        guard let index = project.overlays.firstIndex(where: { $0.layerID == id }) else { return }
        let target = max(0, min(project.overlays.count - 1, index + delta))
        guard target != index else { return }
        let actionName = delta > 0 ? "Bring Forward" : "Send Back"
        applyMutation(actionName) { project in
            let item = project.overlays.remove(at: index)
            project.overlays.insert(item, at: target)
        }
    }

    nonisolated static func cloneOverlayWithFreshID(_ overlay: any Overlay) -> (any Overlay)? {
        let newID = LayerID(UUID().uuidString)
        if let t = overlay as? TextOverlay { return t.id(newID) }
        if let i = overlay as? ImageOverlay { return i.id(newID) }
        if let s = overlay as? StickerOverlay { return s.id(newID) }
        return nil
    }
}
