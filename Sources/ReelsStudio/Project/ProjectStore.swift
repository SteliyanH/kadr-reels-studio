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

    /// Convenience: build a fresh store with the bundled sample clips.
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
}
