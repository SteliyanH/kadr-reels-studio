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
@available(iOS 16, *)
struct TransitionsSheet: View {

    @ObservedObject var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss

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
    }

    // MARK: - Subviews

    @ViewBuilder
    private var kindGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kind")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
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
                    .font(.system(size: 32))
                Text(kind.displayLabel)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2fs", durationSeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $durationSeconds, in: Self.minDuration...Self.maxDuration)
                .accessibilityValue(String(format: "%.2f seconds", durationSeconds))
        }
    }

    @ViewBuilder
    private var removeButton: some View {
        Button(role: .destructive) {
            store.removeTransition(afterClipID: clipID)
            dismiss()
        } label: {
            Label("Remove transition", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.top, 4)
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
@available(iOS 16, *)
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
