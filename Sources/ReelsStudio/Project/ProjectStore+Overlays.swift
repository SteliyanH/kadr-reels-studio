import Foundation
import CoreMedia
import Kadr
import KadrUI

// MARK: - Overlay editing (v0.3 Tier 4)

/// Mutation surface for the overlay-targeted `OverlayInspectorPanel` /
/// `OverlayKeyframeEditor` callbacks. Every entry point routes through
/// ``ProjectStore/applyMutation(actionName:)`` so undo / redo + auto-save
/// inherit.
@MainActor
extension ProjectStore {

    /// Replace the overlay with matching `layerID`. Pure helper — every
    /// per-property mutation below uses it.
    private func updateOverlay(
        id: LayerID,
        actionName: String,
        _ transform: (any Overlay) -> any Overlay
    ) {
        let mapped = project.overlays.map { overlay in
            overlay.layerID == id ? transform(overlay) : overlay
        }
        applyMutation(actionName) { $0.overlays = mapped }
    }

    // MARK: - Common surface (every overlay kind)

    func applyOverlayPosition(id: LayerID, _ position: Position) {
        updateOverlay(id: id, actionName: "Edit Position") { overlay in
            ProjectStore.rebuildOverlay(overlay, position: position)
        }
    }

    func applyOverlaySize(id: LayerID, _ size: Size?) {
        updateOverlay(id: id, actionName: "Edit Size") { overlay in
            ProjectStore.rebuildOverlay(overlay, size: size)
        }
    }

    func applyOverlayAnchor(id: LayerID, _ anchor: Kadr.Anchor) {
        updateOverlay(id: id, actionName: "Edit Anchor") { overlay in
            ProjectStore.rebuildOverlay(overlay, anchor: anchor)
        }
    }

    func applyOverlayOpacity(id: LayerID, _ opacity: Double) {
        updateOverlay(id: id, actionName: "Edit Opacity") { overlay in
            ProjectStore.rebuildOverlay(overlay, opacity: opacity)
        }
    }

    // MARK: - Type-specific

    /// Update the text on a `TextOverlay`. No-op for other overlay kinds.
    func applyOverlayText(id: LayerID, _ text: String) {
        updateOverlay(id: id, actionName: "Edit Text") { overlay in
            guard let textOverlay = overlay as? TextOverlay else { return overlay }
            return TextOverlay(text, style: textOverlay.style)
                .position(textOverlay.position)
                .anchor(textOverlay.anchor)
                .opacity(textOverlay.opacity)
                .id(textOverlay.layerID ?? id)
        }
    }

    /// Replace the `TextAnimation` on a `TextOverlay`. The picker emits
    /// the kind enum; the kadr-ui static `textAnimation(forKind:)` resolves
    /// to a concrete kadr `TextAnimation` (or `nil` to clear).
    func applyOverlayTextAnimation(id: LayerID, _ kind: OverlayTextAnimationKind) {
        updateOverlay(id: id, actionName: "Edit Text Animation") { overlay in
            guard let textOverlay = overlay as? TextOverlay else { return overlay }
            var rebuilt = TextOverlay(textOverlay.text, style: textOverlay.style)
                .position(textOverlay.position)
                .anchor(textOverlay.anchor)
                .opacity(textOverlay.opacity)
                .id(textOverlay.layerID ?? id)
            if let animation = InspectorPanel.textAnimation(forKind: kind) {
                rebuilt = rebuilt.animation(animation)
            }
            return rebuilt
        }
    }

    /// Set a `StickerOverlay`'s rotation in radians. No-op for other kinds.
    func applyOverlayRotation(id: LayerID, _ radians: Double) {
        updateOverlay(id: id, actionName: "Edit Rotation") { overlay in
            guard let sticker = overlay as? StickerOverlay else { return overlay }
            return ProjectStore.rebuildSticker(sticker, rotation: radians)
        }
    }

    // MARK: - Pure rebuild dispatch

    /// Rebuild any overlay kind, overriding the named field. Other fields
    /// preserve from the source. `nil` for `size` clears it (the only
    /// optional). Per-overlay-kind specifics (sticker rotation / shadow,
    /// text content) preserve through the modifier chain.
    nonisolated static func rebuildOverlay(
        _ overlay: any Overlay,
        position: Position? = nil,
        size: Size?? = nil,
        anchor: Kadr.Anchor? = nil,
        opacity: Double? = nil
    ) -> any Overlay {
        if let text = overlay as? TextOverlay {
            return rebuildText(text, position: position, size: size, anchor: anchor, opacity: opacity)
        }
        if let image = overlay as? ImageOverlay {
            return rebuildImage(image, position: position, size: size, anchor: anchor, opacity: opacity)
        }
        if let sticker = overlay as? StickerOverlay {
            return rebuildSticker(sticker, position: position, size: size, anchor: anchor, opacity: opacity)
        }
        return overlay
    }

    nonisolated static func rebuildText(
        _ overlay: TextOverlay,
        position: Position? = nil,
        size: Size?? = nil,
        anchor: Kadr.Anchor? = nil,
        opacity: Double? = nil
    ) -> TextOverlay {
        var rebuilt = TextOverlay(overlay.text, style: overlay.style)
            .position(position ?? overlay.position)
            .anchor(anchor ?? overlay.anchor)
            .opacity(opacity ?? overlay.opacity)
        if let id = overlay.layerID { rebuilt = rebuilt.id(id) }
        // Size: outer-Optional means caller specified; preserve when not.
        if let s = size, let unwrapped = s {
            rebuilt = rebuilt.size(unwrapped)
        } else if size == nil, let existing = overlay.size {
            rebuilt = rebuilt.size(existing)
        }
        if let animation = overlay.textAnimation {
            rebuilt = rebuilt.animation(animation)
        }
        return rebuilt
    }

    nonisolated static func rebuildImage(
        _ overlay: ImageOverlay,
        position: Position? = nil,
        size: Size?? = nil,
        anchor: Kadr.Anchor? = nil,
        opacity: Double? = nil
    ) -> ImageOverlay {
        var rebuilt = ImageOverlay(overlay.image)
            .position(position ?? overlay.position)
            .anchor(anchor ?? overlay.anchor)
            .opacity(opacity ?? overlay.opacity)
        if let id = overlay.layerID { rebuilt = rebuilt.id(id) }
        if let s = size, let unwrapped = s {
            rebuilt = rebuilt.size(unwrapped)
        } else if size == nil, let existing = overlay.size {
            rebuilt = rebuilt.size(existing)
        }
        if let positionAnim = overlay.positionAnimation {
            rebuilt = rebuilt.positionAnimation(positionAnim)
        }
        if let sizeAnim = overlay.sizeAnimation {
            rebuilt = rebuilt.sizeAnimation(sizeAnim)
        }
        return rebuilt
    }

    nonisolated static func rebuildSticker(
        _ overlay: StickerOverlay,
        position: Position? = nil,
        size: Size?? = nil,
        anchor: Kadr.Anchor? = nil,
        opacity: Double? = nil,
        rotation: Double? = nil
    ) -> StickerOverlay {
        var rebuilt = StickerOverlay(overlay.image)
            .position(position ?? overlay.position)
            .anchor(anchor ?? overlay.anchor)
            .opacity(opacity ?? overlay.opacity)
            .rotation(rotation ?? overlay.rotation)
        if let id = overlay.layerID { rebuilt = rebuilt.id(id) }
        if let s = size, let unwrapped = s {
            rebuilt = rebuilt.size(unwrapped)
        } else if size == nil, let existing = overlay.size {
            rebuilt = rebuilt.size(existing)
        }
        if let shadow = overlay.shadow { rebuilt = rebuilt.shadow(shadow) }
        if let positionAnim = overlay.positionAnimation {
            rebuilt = rebuilt.positionAnimation(positionAnim)
        }
        if let sizeAnim = overlay.sizeAnimation {
            rebuilt = rebuilt.sizeAnimation(sizeAnim)
        }
        return rebuilt
    }
}

// MARK: - Overlay keyframe authoring

@MainActor
extension ProjectStore {

    /// Add a keyframe at `time` for `property` (`.position` or `.size`)
    /// on the identified overlay. Value sampled from the overlay's current
    /// static property. Only `ImageOverlay` / `StickerOverlay` participate
    /// — `TextOverlay` keyframes use the enum-driven `textAnimation`
    /// surface instead.
    func addOverlayKeyframe(layerID: LayerID, property: OverlayProperty, time: CMTime) {
        updateOverlay(id: layerID, actionName: "Add Keyframe") { overlay in
            ProjectStore.upsertOverlayKeyframe(overlay, property: property, time: time)
        }
    }

    func removeOverlayKeyframe(layerID: LayerID, property: OverlayProperty, time: CMTime) {
        updateOverlay(id: layerID, actionName: "Remove Keyframe") { overlay in
            ProjectStore.removeOverlayKeyframe(overlay, property: property, at: time)
        }
    }

    func retimeOverlayKeyframe(layerID: LayerID, property: OverlayProperty, from: CMTime, to: CMTime) {
        updateOverlay(id: layerID, actionName: "Move Keyframe") { overlay in
            ProjectStore.retimeOverlayKeyframe(overlay, property: property, from: from, to: to)
        }
    }

    // MARK: - Pure overlay-keyframe transforms

    nonisolated static func upsertOverlayKeyframe(
        _ overlay: any Overlay,
        property: OverlayProperty,
        time: CMTime
    ) -> any Overlay {
        switch property {
        case .position:
            let value = overlay.position
            let updated = upsertKeyframe(overlay.positionAnimation, time: time, value: value)
            return setPositionAnimation(overlay, animation: updated)
        case .size:
            let value = overlay.size ?? .normalized(width: 1.0, height: 1.0)
            let updated = upsertKeyframe(overlay.sizeAnimation, time: time, value: value)
            return setSizeAnimation(overlay, animation: updated)
        }
    }

    nonisolated static func removeOverlayKeyframe(
        _ overlay: any Overlay,
        property: OverlayProperty,
        at time: CMTime
    ) -> any Overlay {
        switch property {
        case .position:
            let updated = removingKeyframe(overlay.positionAnimation, at: time)
            return setPositionAnimation(overlay, animation: updated)
        case .size:
            let updated = removingKeyframe(overlay.sizeAnimation, at: time)
            return setSizeAnimation(overlay, animation: updated)
        }
    }

    nonisolated static func retimeOverlayKeyframe(
        _ overlay: any Overlay,
        property: OverlayProperty,
        from: CMTime,
        to: CMTime
    ) -> any Overlay {
        switch property {
        case .position:
            let updated = retimingKeyframe(overlay.positionAnimation, from: from, to: to)
            return setPositionAnimation(overlay, animation: updated)
        case .size:
            let updated = retimingKeyframe(overlay.sizeAnimation, from: from, to: to)
            return setSizeAnimation(overlay, animation: updated)
        }
    }

    // MARK: - Per-overlay-kind animation setters (uses kadr v0.10.1 modifiers)

    nonisolated static func setPositionAnimation(
        _ overlay: any Overlay,
        animation: Kadr.Animation<Position>?
    ) -> any Overlay {
        if let image = overlay as? ImageOverlay {
            return image.positionAnimation(animation)
        }
        if let sticker = overlay as? StickerOverlay {
            return sticker.positionAnimation(animation)
        }
        // TextOverlay / Watermark — no positionAnimation surface.
        return overlay
    }

    nonisolated static func setSizeAnimation(
        _ overlay: any Overlay,
        animation: Kadr.Animation<Size>?
    ) -> any Overlay {
        if let image = overlay as? ImageOverlay {
            return image.sizeAnimation(animation)
        }
        if let sticker = overlay as? StickerOverlay {
            return sticker.sizeAnimation(animation)
        }
        return overlay
    }
}
