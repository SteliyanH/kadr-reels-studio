import SwiftUI
import Kadr

/// Two-tier bottom toolbar — selection-driven swap. CapCut / VN pattern: the
/// row above the timeline shows root verbs (`+ Clip` / `+ Overlay` / etc.) when
/// nothing's selected, swaps to clip-action verbs when a clip is selected,
/// and to overlay-action verbs when an overlay is selected.
///
/// v0.4 Tier 1a ships the state machine + Duplicate / Delete / Speed / Bring-
/// forward / Send-back actions. Split + Filters land in Tier 1b — the clip
/// row reserves their slots but renders them disabled until that PR.
struct EditorToolbar: View {

    @ObservedObject var store: ProjectStore
    @EnvironmentObject private var toasts: ToastCenter

    // Root-row callbacks — owned by `EditorView` so it can present sheets.
    var onAddClip: () -> Void
    var onAddOverlay: () -> Void
    var onLayers: () -> Void
    var onAddMusic: () -> Void
    var onAddSFX: () -> Void
    var onAddCaptions: () -> Void
    var onExport: () -> Void

    // Clip-row callbacks that need a sheet — also owned by the editor.
    var onSpeedCurve: (ClipID) -> Void
    var onFilters: (ClipID) -> Void = { _ in }

    private enum Mode: Equatable { case root, clip(ClipID), overlay(LayerID) }

    private var mode: Mode {
        if let id = store.selectedOverlayID { return .overlay(id) }
        if let id = store.selectedClipID { return .clip(id) }
        return .root
    }

    var body: some View {
        Group {
            switch mode {
            case .root:
                rootRow
                    .transition(.opacity)
            case .clip(let id):
                clipRow(id: id)
                    .transition(.opacity)
            case .overlay(let id):
                overlayRow(id: id)
                    .transition(.opacity)
            }
        }
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.78), value: mode)
        .padding(.horizontal)
    }

    // MARK: - Root row

    @ViewBuilder
    private var rootRow: some View {
        HStack(spacing: 12) {
            ToolbarButton(systemImage: "plus.rectangle", label: "Clip", action: onAddClip)
            ToolbarButton(systemImage: "textformat", label: "Overlay", action: onAddOverlay)
            ToolbarButton(systemImage: "square.stack.3d.up", label: "Layers", action: onLayers)
            ToolbarButton(systemImage: "music.note", label: "Music", action: onAddMusic)
            ToolbarButton(systemImage: "speaker.wave.2", label: "SFX", action: onAddSFX)
            ToolbarButton(systemImage: "captions.bubble", label: "Captions", action: onAddCaptions)
            Spacer()
            ToolbarButton(systemImage: "square.and.arrow.up", label: "Export", action: onExport)
        }
    }

    // MARK: - Clip-action row

    @ViewBuilder
    private func clipRow(id: ClipID) -> some View {
        HStack(spacing: 12) {
            ToolbarButton(systemImage: "scissors", label: "Split") {
                let result = store.splitClip(id: id, at: store.currentTime)
                if result != .ok {
                    toasts.show(.transient(message: "Can't split", detail: EditorToolbar.splitFailureDetail(result)))
                }
            }
            ToolbarButton(systemImage: "doc.on.doc", label: "Duplicate") {
                store.duplicateClip(id: id)
            }
            ToolbarButton(systemImage: "speedometer", label: "Speed") {
                onSpeedCurve(id)
            }
            ToolbarButton(systemImage: "camera.filters", label: "Filters") {
                onFilters(id)
            }
            Spacer()
            ToolbarButton(systemImage: "trash", label: "Delete", role: .destructive) {
                HapticEngine.shared.thud()
                store.removeClip(id: id)
            }
        }
    }

    // MARK: - Overlay-action row

    @ViewBuilder
    private func overlayRow(id: LayerID) -> some View {
        HStack(spacing: 12) {
            ToolbarButton(systemImage: "doc.on.doc", label: "Duplicate") {
                store.duplicateOverlay(id: id)
            }
            ToolbarButton(systemImage: "square.3.stack.3d.top.fill", label: "Forward") {
                store.moveOverlay(id: id, by: 1)
            }
            ToolbarButton(systemImage: "square.3.stack.3d.bottom.fill", label: "Back") {
                store.moveOverlay(id: id, by: -1)
            }
            Spacer()
            ToolbarButton(systemImage: "trash", label: "Delete", role: .destructive) {
                HapticEngine.shared.thud()
                store.removeOverlay(id: id)
            }
        }
    }
}

extension EditorToolbar {
    /// User-facing detail for each `splitClip` failure mode.
    static func splitFailureDetail(_ result: ProjectStore.SplitResult) -> String {
        switch result {
        case .ok: return ""
        case .clipNotFound: return "The selected clip is no longer in the project."
        case .clipInsideTrack: return "Clips inside a track aren't splittable yet."
        case .offsetOutOfRange: return "Move the playhead inside the clip and try again."
        case .unsupportedSpeedRate: return "Clear the speed rate before splitting."
        }
    }
}

private struct ToolbarButton: View {
    let systemImage: String
    let label: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(minWidth: 56, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}
