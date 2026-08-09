import SwiftUI
import Kadr
import KadrUI

/// Top half of the editor — `VideoPreview` (AVKit player) overlaid with `OverlayHost`
/// (gesture-routed overlays). Aspect ratio locked to the project preset's resolution.
struct PreviewArea: View {

    var store: ProjectStore

    var body: some View {
        let video = store.video
        let aspect = video.preset.resolution.width / video.preset.resolution.height

        ZStack {
            VideoPreview(video)
            OverlayHost(video, currentTime: store.currentTime)
                // v0.4 Tier 6: tap an overlay's hit region to select it.
                // Routes to the same selection slot the Layers sheet writes,
                // so the inspector / keyframe pair swaps the moment a layer
                // is tapped. v0.3's LayersSheet stays as the secondary
                // affordance (still useful for stacked or off-screen layers).
                .onLayerTap { id in
                    store.selectedOverlayID = id
                }
        }
        .aspectRatio(aspect, contentMode: .fit)
        // v0.8 Tier 3 — the letterbox stays true black: this is the field the
        // user grades against, so it takes the stage token rather than a
        // ground-tinted role. Decision 5's "never grayscale the stage" applies
        // to the same surface for the same reason.
        .background(Modernist.stageInk)
        .clipShape(RoundedRectangle(cornerRadius: Modernist.Radius.md))
    }
}
