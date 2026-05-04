import Foundation
import Combine
import CoreMedia
import Kadr

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
    @Published var selectedClipID: ClipID?

    /// Composition-time playhead. Driven by `TimelineView`'s tap-to-scrub.
    @Published var currentTime: CMTime = .zero

    init(project: Project) {
        self.project = project
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

    // MARK: - Mutations

    func append(clip: any Clip) {
        project.clips.append(clip)
    }

    func append(clips newClips: [any Clip]) {
        project.clips.append(contentsOf: newClips)
    }

    func append(overlay: any Overlay) {
        project.overlays.append(overlay)
    }

    func append(audioTrack: AudioTrack) {
        project.audioTracks.append(audioTrack)
    }

    func append(captions newCaptions: [Caption]) {
        project.captions.append(contentsOf: newCaptions)
    }

    func setPreset(_ preset: Preset) {
        project.preset = preset
    }

    /// Swap two top-level chain clips. The timeline's `onReorder` callback hands us
    /// the new array directly — we just replace.
    func replaceClips(_ newClips: [any Clip]) {
        project.clips = newClips
    }

    /// Find the chain clip with the given `ClipID` and replace it with the result of
    /// `transform`. No-op if the ID isn't found. Used by the inspector to apply
    /// `Transform` / opacity / filter-intensity edits without rebuilding the
    /// entire clip array.
    func updateClip(id: ClipID, _ transform: (any Clip) -> any Clip) {
        project.clips = project.clips.map { clip in
            clip.clipID == id ? transform(clip) : clip
        }
    }

    /// Apply a Transform to the selected clip (across `VideoClip` / `ImageClip` /
    /// `TitleSequence`).
    func applyTransform(id: ClipID, _ t: Transform) {
        updateClip(id: id) { clip in
            if let v = clip as? VideoClip { return v.transform(t) }
            if let i = clip as? ImageClip { return i.transform(t) }
            if let title = clip as? TitleSequence { return title.transform(t) }
            return clip
        }
    }

    /// Apply opacity (0...1) to the selected clip.
    func applyOpacity(id: ClipID, _ opacity: Double) {
        updateClip(id: id) { clip in
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
        updateClip(id: id) { clip in
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
