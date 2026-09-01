import SwiftUI
import CoreMedia
import Kadr

/// Picker sheet for the transition between the selected clip and its
/// successor. v0.7 Tier 2.
///
/// Pushed from the clip-action toolbar's "Transition" button. Seeds the
/// kind + duration from any existing transition at the gap, falling back
/// to `.fade` / `0.5s` for a fresh insert. Apply commits via
/// `ProjectStore.insertTransition(afterClipID:kind:duration:)` — the
/// mutation replaces an existing transition at the same gap or inserts a
/// new one, so the sheet doesn't have to branch.
struct TransitionsSheet: View {

    var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette

    @State private var selectedKind: TransitionKind
    @State private var durationSeconds: Double

    /// Smallest sensible transition duration. Anything under 100ms reads as
    /// a hard cut on most playback hardware.
    private static let minDuration: Double = 0.1
    /// Upper bound for a single-gap transition. Matches CapCut's default
    /// slider top — most users don't reach for longer than 2s.
    private static let maxDuration: Double = 2.0

    init(store: ProjectStore, clipID: ClipID) {
        self.store = store
        self.clipID = clipID
        if let current = ProjectStore.currentTransition(afterClipID: clipID, in: store.project.clips) {
            _selectedKind = State(initialValue: current.kind)
            _durationSeconds = State(initialValue: CMTimeGetSeconds(current.duration))
        } else {
            _selectedKind = State(initialValue: .fade)
            _durationSeconds = State(initialValue: 0.5)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Transition") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
                Button("Apply") {
                    apply()
                    dismiss()
                }
                .buttonStyle(ReelPrimaryButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Reel.Space.s6) {
                    kindGrid
                    durationSection
                    if existingTransitionPresent {
                        removeButton
                    }
                }
                .padding(Reel.Space.s4)
            }
        }
        .reelSheet(Reel.SheetDetent.settings)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var kindGrid: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Kind")
                .reelLabel()
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: Reel.Space.s2),
                    count: Reel.presetGridColumns
                ),
                spacing: Reel.Space.s2
            ) {
                ForEach(TransitionKind.allCases, id: \.self) { kind in
                    transitionTile(kind: kind)
                }
            }
        }
    }

    @ViewBuilder
    private func transitionTile(kind: TransitionKind) -> some View {
        let isSelected = kind == selectedKind
        Button {
            selectedKind = kind
        } label: {
            VStack(alignment: .leading, spacing: Reel.Space.s2) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: Reel.Typography.Glyph.md, weight: Reel.Typography.headingWeight))
                Text(kind.displayLabel)
                    .font(Reel.Typography.bodyEmphasis)
            }
            // Icon over label, both flush left — the system's alignment rule.
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: Reel.minHitTarget + Reel.Space.s6)
            .padding(Reel.Space.s3)
            // v0.8 Tier 3 — the selected-cell pattern for the whole app: a
            // named `accentTint` fill (never an ad-hoc accent opacity) and a
            // 2pt accent rule.
            .background(isSelected ? palette.accentTint : palette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: palette.radius.md)
                    .stroke(isSelected ? palette.accent : .clear, lineWidth: palette.ruleWidth)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(kind.displayLabel)
    }

    @ViewBuilder
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Duration")
                .reelLabel()
            ReelSlider(
                label: NSLocalizedString("Duration", comment: "Transition duration"),
                value: $durationSeconds,
                range: Self.minDuration...Self.maxDuration,
                valueText: String(format: "%.2fs", durationSeconds)
            )
            // The v0.7 spoken value survives the control swap verbatim: the
            // slider's own combined value would read "0.50s", and VoiceOver
            // has always said "0.50 seconds" here.
            .accessibilityValue(String(format: "%.2f seconds", durationSeconds))
        }
    }

    @ViewBuilder
    private var removeButton: some View {
        // Decision 4 — the accent already *is* red, so destructive is the
        // accent-outlined secondary style plus the trash glyph, never a
        // second red fill.
        Button(role: .destructive) {
            store.removeTransition(afterClipID: clipID)
            dismiss()
        } label: {
            Label("Remove transition", systemImage: "trash")
        }
        .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
        .padding(.top, Reel.Space.s1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - State

    private var existingTransitionPresent: Bool {
        ProjectStore.hasTransitionAfter(clipID: clipID, in: store.project.clips)
    }

    private func apply() {
        store.insertTransition(
            afterClipID: clipID,
            kind: selectedKind,
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
    }
}

// v0.8 Tier 5a — the `navigationBarTitleDisplayModeInline()` shim went with
// the `NavigationStack` this sheet no longer wraps itself in. The sheet's
// title is drawn by `ReelSheetHeader`, so there is no system navigation
// bar left to configure.
