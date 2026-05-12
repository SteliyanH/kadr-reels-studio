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
    /// when the clip isn't a `VideoClip` or the index is out of range.
    ///
    /// v0.6 — migrated to kadr v0.11's keyed `removeFilter(for:)` API.
    /// Pre-v0.6 we walked filters + re-added each via `.filter(_:)`, which
    /// re-issued every `FilterID` and orphaned any bound animation. The
    /// keyed surface drops the slot and its animation atomically while
    /// leaving neighbors' identities untouched.
    func removeFilter(id: ClipID, filterIndex: Int) {
        updateClip(id: id, actionName: "Remove Filter") { clip in
            guard let video = clip as? VideoClip else { return clip }
            guard filterIndex >= 0, filterIndex < video.filterIDs.count else { return clip }
            let filterID = video.filterIDs[filterIndex]
            return video.removeFilter(for: filterID)
        }
    }
}
