import SwiftUI
import Kadr
import KadrUI

/// Top half of the editor — `VideoPreview` (AVKit player) overlaid with `OverlayHost`
/// (gesture-routed overlays). Aspect ratio locked to the project preset's resolution.
struct PreviewArea: View {

    @ObservedObject var store: ProjectStore

    var body: some View {
        let video = store.video
        let aspect = video.preset.resolution.width / video.preset.resolution.height

        ZStack {
            VideoPreview(video)
            OverlayHost(video, currentTime: store.currentTime)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
