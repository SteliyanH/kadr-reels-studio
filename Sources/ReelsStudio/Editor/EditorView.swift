import SwiftUI

/// Root editor screen. Composes ``PreviewArea`` (top) + ``TimelineArea`` (bottom)
/// against a ``ProjectStore``.
///
/// Tier 1 walking skeleton — no clip / overlay / music sheets yet (Tiers 2 / 3),
/// no inspector / keyframe editor (Tier 4), no caption ingest (Tier 5), no
/// export flow (Tier 6).
struct EditorView: View {

    @StateObject private var store = ProjectStore.sample()
    @State private var showPhotoPicker = false
    @State private var showOverlaySheet = false
    @State private var showMusicSheet = false
    @State private var showSFXSheet = false

    var body: some View {
        VStack(spacing: 16) {
            PreviewArea(store: store)
                .padding(.horizontal)
            Spacer(minLength: 8)
            TimelineArea(
                store: store,
                onAddClip: { showPhotoPicker = true },
                onAddOverlay: { showOverlaySheet = true },
                onAddMusic: { showMusicSheet = true },
                onAddSFX: { showSFXSheet = true }
            )
            if store.selectedClipID != nil {
                KeyframeArea(store: store)
                InspectorArea(store: store)
                    .padding(.horizontal)
            }
            Spacer(minLength: 16)
        }
        .padding(.top)
        .background(Color(.systemGray6).ignoresSafeArea())
        .addClipFlow(isPresented: $showPhotoPicker, store: store)
        .sheet(isPresented: $showOverlaySheet) {
            AddOverlaySheet(store: store)
        }
        .sheet(isPresented: $showMusicSheet) {
            AddMusicSheet(store: store)
        }
        .sheet(isPresented: $showSFXSheet) {
            AddSFXSheet(store: store)
        }
    }
}

#Preview {
    EditorView()
}
