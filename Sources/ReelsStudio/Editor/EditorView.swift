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

    var body: some View {
        VStack(spacing: 16) {
            PreviewArea(store: store)
                .padding(.horizontal)
            Spacer(minLength: 8)
            TimelineArea(
                store: store,
                onAddClip: { showPhotoPicker = true }
            )
            Spacer(minLength: 16)
        }
        .padding(.top)
        .background(Color(.systemGray6).ignoresSafeArea())
        .addClipFlow(isPresented: $showPhotoPicker, store: store)
    }
}

#Preview {
    EditorView()
}
