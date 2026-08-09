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
    @Environment(\.modernistPalette) private var palette

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    kindGrid
                    durationSection
                    if existingTransitionPresent {
                        removeButton
                    }
                }
                .padding()
            }
            .navigationTitle("Transition")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        apply()
                        dismiss()
                    }
                }
            }
        }
        // v0.8 Tier 2 — sheets are chrome; chrome is the print ground.
        .modernistSurface(.print)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var kindGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kind")
                .modernistLabel()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)], spacing: 12) {
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
            VStack(spacing: 6) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: Modernist.Typography.Glyph.md, weight: Modernist.Typography.headingWeight))
                Text(kind.displayLabel)
                    .font(Modernist.Typography.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(8)
            // v0.8 Tier 3 — the selected-cell pattern for the whole app: a
            // named `accentTint` fill (never an ad-hoc accent opacity) and a
            // 2pt accent rule.
            .background(
                RoundedRectangle(cornerRadius: Modernist.Radius.md)
                    .fill(isSelected ? palette.accentTint : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Modernist.Radius.md)
                    .stroke(isSelected ? palette.accent : .clear, lineWidth: Modernist.ruleWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel(kind.displayLabel)
    }

    @ViewBuilder
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duration")
                    .modernistLabel()
                Spacer()
                Text(String(format: "%.2fs", durationSeconds))
                    .font(Modernist.Typography.numeric)
                    .foregroundStyle(palette.textMuted)
            }
            Slider(value: $durationSeconds, in: Self.minDuration...Self.maxDuration)
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
        .buttonStyle(ModernistSecondaryButtonStyle(isBlock: true))
        .padding(.top, Modernist.Space.s1)
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

/// `.navigationBarTitleDisplayMode(.inline)` is iOS-only. Same shim pattern
/// the editor uses.
private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
