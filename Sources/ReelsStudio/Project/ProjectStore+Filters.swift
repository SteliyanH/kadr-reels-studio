import Foundation
import Kadr

/// Filter-list mutations powering ``FiltersSheet``. `applyFilterIntensity` for
/// per-filter scalar editing already lives on ``ProjectStore`` (since v0.1);
/// this extension covers append + remove.
@MainActor
extension ProjectStore {

    /// Append `filter` to the selected `VideoClip`'s filter stack. No-op when
    /// the clip isn't a `VideoClip`. Routes through the standard
    /// `updateClip(id:actionName:_:)` so undo / auto-save inherit.
    func addFilter(id: ClipID, _ filter: Filter) {
        updateClip(id: id, actionName: "Add Filter") { clip in
            guard let video = clip as? VideoClip else { return clip }
            return video.filter(filter)
        }
    }

    /// Remove the filter at `filterIndex` from the selected `VideoClip`. No-op
    /// when the clip isn't a `VideoClip` or the index is out of range. Rebuilds
    /// the clip with the new filter list — kadr's modifier surface doesn't
    /// expose a remove-filter modifier, so we walk the existing filters and
    /// drop the indexed one.
    func removeFilter(id: ClipID, filterIndex: Int) {
        updateClip(id: id, actionName: "Remove Filter") { clip in
            guard let video = clip as? VideoClip else { return clip }
            guard filterIndex >= 0, filterIndex < video.filters.count else { return clip }
            var rebuilt = VideoClip(url: video.url)
            if let trim = video.trimRange { rebuilt = rebuilt.trimmed(to: trim) }
            for (i, filter) in video.filters.enumerated() where i != filterIndex {
                rebuilt = rebuilt.filter(filter)
            }
            if let cid = video.clipID { rebuilt = rebuilt.id(cid) }
            if let t = video.transform { rebuilt = rebuilt.transform(t) }
            if let o = video.opacity { rebuilt = rebuilt.opacity(o) }
            return rebuilt
        }
    }
}
