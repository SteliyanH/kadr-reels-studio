import Foundation
import CoreMedia
import Kadr

/// UI-friendly mirror of `Kadr.Transition`'s cases.
///
/// Decouples the transitions picker sheet from kadr's type so the sheet can
/// enumerate available kinds via `allCases`, render labels + SF Symbol
/// glyphs, and round-trip a selection through `ProjectStore` without the
/// sheet view importing kadr directly. Mirrors the pattern `ProjectFilter`
/// uses for the filter picker. v0.7 Tier 2.
public enum TransitionKind: String, CaseIterable, Sendable, Equatable {
    case fade
    case dissolve

    /// Display label surfaced in the picker grid + Edit-menu undo entries.
    public var displayLabel: String {
        switch self {
        case .fade:     return "Fade"
        case .dissolve: return "Dissolve"
        }
    }

    /// SF Symbol name for the picker tile. Both kinds share the same glyph
    /// family — kadr ships only fade + dissolve today, and visually a
    /// crossfade reads as the same arrow icon at this tile size. The tile
    /// label disambiguates.
    public var systemImage: String {
        switch self {
        case .fade:     return "circle.lefthalf.filled"
        case .dissolve: return "circle.righthalf.filled"
        }
    }

    /// Build the kadr `Transition` for this kind at the given duration.
    /// Used by `ProjectStore.insertingTransition` when applying the picker
    /// selection.
    public func makeTransition(duration: CMTime) -> Kadr.Transition {
        switch self {
        case .fade:     return .fade(duration: duration)
        case .dissolve: return .dissolve(duration: duration)
        }
    }
}
