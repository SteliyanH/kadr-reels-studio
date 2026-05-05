import Foundation
import CoreMedia
import Kadr
import KadrUI

// MARK: - Keyframe authoring (v0.3)

/// Mutation surface for `KadrUI.KeyframeEditor` callbacks. Every entry point
/// routes through ``ProjectStore/updateClip(id:actionName:_:)`` so undo /
/// redo + auto-save Just Work.
///
/// **Time domain.** `KeyframeEditor` reports clip-relative seconds; kadr's
/// `Animation<T>.Keyframe.time` is also clip-relative. No remapping needed.
@MainActor
extension ProjectStore {

    /// Add a keyframe at `time` for `property`. The keyframe's value is
    /// sampled from the clip's current static property:
    /// - `.transform` → current `transform ?? .identity`
    /// - `.opacity` → current `opacity ?? 1.0`
    /// - `.filter(index:)` → current scalar of `filters[index]`
    /// A future tier can add an explicit-value path; for v0.3 the user
    /// add-then-edit-the-static-value flow is the expected sequence.
    func addKeyframe(clipID: ClipID, property: KeyframeProperty, time: CMTime) {
        switch property {
        case .transform:
            updateClip(id: clipID, actionName: "Add Keyframe") { clip in
                let current = ProjectStore.transform(of: clip) ?? .identity
                let updated = ProjectStore.upsertKeyframe(
                    ProjectStore.transformAnimation(of: clip),
                    time: time,
                    value: current
                )
                return ProjectStore.applyTransformAnimation(clip, base: current, animation: updated)
            }
        case .opacity:
            updateClip(id: clipID, actionName: "Add Keyframe") { clip in
                let current = ProjectStore.opacity(of: clip) ?? 1.0
                let updated = ProjectStore.upsertKeyframe(
                    ProjectStore.opacityAnimation(of: clip),
                    time: time,
                    value: current
                )
                return ProjectStore.applyOpacityAnimation(clip, base: current, animation: updated)
            }
        case .filter(let index):
            updateClip(id: clipID, actionName: "Add Keyframe") { clip in
                guard let video = clip as? VideoClip,
                      index >= 0, index < video.filters.count,
                      let scalar = ProjectStore.scalar(of: video.filters[index]) else { return clip }
                let existing = index < video.filterAnimations.count ? video.filterAnimations[index] : nil
                let updated = ProjectStore.upsertKeyframe(existing, time: time, value: scalar)
                return ProjectStore.applyFilterAnimation(video, filterIndex: index, animation: updated)
            }
        }
    }

    /// Remove the keyframe at `time` for `property`. No-op if no keyframe
    /// exists at that time.
    func removeKeyframe(clipID: ClipID, property: KeyframeProperty, time: CMTime) {
        switch property {
        case .transform:
            updateClip(id: clipID, actionName: "Remove Keyframe") { clip in
                let updated = ProjectStore.removingKeyframe(
                    ProjectStore.transformAnimation(of: clip),
                    at: time
                )
                let base = ProjectStore.transform(of: clip) ?? .identity
                return ProjectStore.applyTransformAnimation(clip, base: base, animation: updated)
            }
        case .opacity:
            updateClip(id: clipID, actionName: "Remove Keyframe") { clip in
                let updated = ProjectStore.removingKeyframe(
                    ProjectStore.opacityAnimation(of: clip),
                    at: time
                )
                let base = ProjectStore.opacity(of: clip) ?? 1.0
                return ProjectStore.applyOpacityAnimation(clip, base: base, animation: updated)
            }
        case .filter(let index):
            updateClip(id: clipID, actionName: "Remove Keyframe") { clip in
                guard let video = clip as? VideoClip,
                      index >= 0, index < video.filterAnimations.count else { return clip }
                let existing = video.filterAnimations[index]
                let updated = ProjectStore.removingKeyframe(existing, at: time)
                return ProjectStore.applyFilterAnimation(video, filterIndex: index, animation: updated)
            }
        }
    }

    /// Move the keyframe at `from` to `to`.
    func retimeKeyframe(clipID: ClipID, property: KeyframeProperty, from: CMTime, to: CMTime) {
        switch property {
        case .transform:
            updateClip(id: clipID, actionName: "Move Keyframe") { clip in
                let updated = ProjectStore.retimingKeyframe(
                    ProjectStore.transformAnimation(of: clip),
                    from: from, to: to
                )
                let base = ProjectStore.transform(of: clip) ?? .identity
                return ProjectStore.applyTransformAnimation(clip, base: base, animation: updated)
            }
        case .opacity:
            updateClip(id: clipID, actionName: "Move Keyframe") { clip in
                let updated = ProjectStore.retimingKeyframe(
                    ProjectStore.opacityAnimation(of: clip),
                    from: from, to: to
                )
                let base = ProjectStore.opacity(of: clip) ?? 1.0
                return ProjectStore.applyOpacityAnimation(clip, base: base, animation: updated)
            }
        case .filter(let index):
            updateClip(id: clipID, actionName: "Move Keyframe") { clip in
                guard let video = clip as? VideoClip,
                      index >= 0, index < video.filterAnimations.count else { return clip }
                let existing = video.filterAnimations[index]
                let updated = ProjectStore.retimingKeyframe(existing, from: from, to: to)
                return ProjectStore.applyFilterAnimation(video, filterIndex: index, animation: updated)
            }
        }
    }

    // MARK: - Pure animation transforms (testable)

    nonisolated static func upsertKeyframe<T>(
        _ existing: Kadr.Animation<T>?,
        time: CMTime,
        value: T
    ) -> Kadr.Animation<T> {
        let timing = existing?.timing ?? .linear
        var keyframes = (existing?.keyframes ?? []).filter { $0.time.value != time.value }
        keyframes.append(Kadr.Animation<T>.Keyframe.at(time, value: value))
        return Kadr.Animation<T>.keyframes(keyframes, timing: timing)
    }

    nonisolated static func removingKeyframe<T>(
        _ existing: Kadr.Animation<T>?,
        at time: CMTime
    ) -> Kadr.Animation<T>? {
        guard let existing else { return nil }
        let filtered = existing.keyframes.filter { $0.time.value != time.value }
        guard !filtered.isEmpty else { return nil }
        return Kadr.Animation<T>.keyframes(filtered, timing: existing.timing)
    }

    nonisolated static func retimingKeyframe<T>(
        _ existing: Kadr.Animation<T>?,
        from: CMTime,
        to: CMTime
    ) -> Kadr.Animation<T>? {
        guard let existing,
              let moved = existing.keyframes.first(where: { $0.time.value == from.value }) else {
            return existing
        }
        var keyframes = existing.keyframes.filter {
            $0.time.value != from.value && $0.time.value != to.value
        }
        keyframes.append(Kadr.Animation<T>.Keyframe.at(to, value: moved.value))
        return Kadr.Animation<T>.keyframes(keyframes, timing: existing.timing)
    }

    // MARK: - Property accessors / clip rebuild dispatch

    nonisolated static func transform(of clip: any Clip) -> Transform? {
        if let v = clip as? VideoClip { return v.transform }
        if let i = clip as? ImageClip { return i.transform }
        if let t = clip as? TitleSequence { return t.transform }
        return nil
    }

    nonisolated static func transformAnimation(of clip: any Clip) -> Kadr.Animation<Transform>? {
        if let v = clip as? VideoClip { return v.transformAnimation }
        if let i = clip as? ImageClip { return i.transformAnimation }
        if let t = clip as? TitleSequence { return t.transformAnimation }
        return nil
    }

    nonisolated static func opacity(of clip: any Clip) -> Double? {
        if let v = clip as? VideoClip { return v.opacity }
        if let i = clip as? ImageClip { return i.opacity }
        if let t = clip as? TitleSequence { return t.opacity }
        return nil
    }

    nonisolated static func opacityAnimation(of clip: any Clip) -> Kadr.Animation<Double>? {
        if let v = clip as? VideoClip { return v.opacityAnimation }
        if let i = clip as? ImageClip { return i.opacityAnimation }
        if let t = clip as? TitleSequence { return t.opacityAnimation }
        return nil
    }

    /// Local mirror of kadr's `InspectorPanel.scalar(of:)` (which is internal
    /// in kadr-ui v0.8). Returns `nil` for filters without a scalar parameter
    /// (`mono` / `lut` / `chromaKey`).
    nonisolated static func scalar(of filter: Filter) -> Double? {
        switch filter {
        case .brightness(let v): return v
        case .contrast(let v): return v
        case .saturation(let v): return v
        case .exposure(let v): return v
        case .sepia(let v): return v
        case .gaussianBlur(let v): return v
        case .vignette(let v): return v
        case .sharpen(let v): return v
        case .zoomBlur(let v): return v
        case .glow(let v): return v
        case .mono, .lut, .chromaKey: return nil
        }
    }

    /// Apply (or clear) the transform animation. Routes through kadr v0.10.1's
    /// `transformAnimation(_:)` setter modifiers which install or clear the
    /// animation field while preserving every other clip property. Static
    /// base value lands via the existing `.transform(_:)` modifier.
    nonisolated static func applyTransformAnimation(
        _ clip: any Clip,
        base: Transform,
        animation: Kadr.Animation<Transform>?
    ) -> any Clip {
        if let v = clip as? VideoClip {
            return v.transform(base).transformAnimation(animation)
        }
        if let i = clip as? ImageClip {
            return i.transform(base).transformAnimation(animation)
        }
        if let t = clip as? TitleSequence {
            return t.transform(base).transformAnimation(animation)
        }
        return clip
    }

    nonisolated static func applyOpacityAnimation(
        _ clip: any Clip,
        base: Double,
        animation: Kadr.Animation<Double>?
    ) -> any Clip {
        if let v = clip as? VideoClip {
            return v.opacity(base).opacityAnimation(animation)
        }
        if let i = clip as? ImageClip {
            return i.opacity(base).opacityAnimation(animation)
        }
        if let t = clip as? TitleSequence {
            return t.opacity(base).opacityAnimation(animation)
        }
        return clip
    }

    /// Apply (or clear) the animation on `filters[filterIndex]`. Routes
    /// through kadr v0.10.1's `filterAnimation(at:_:)` setter which
    /// addresses the indexed slot directly without disturbing siblings.
    nonisolated static func applyFilterAnimation(
        _ video: VideoClip,
        filterIndex: Int,
        animation: Kadr.Animation<Double>?
    ) -> VideoClip {
        video.filterAnimation(at: filterIndex, animation)
    }
}
