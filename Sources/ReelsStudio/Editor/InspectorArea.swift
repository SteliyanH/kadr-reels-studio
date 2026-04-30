import SwiftUI
import Kadr
import KadrUI

/// Inspector panel — slides in when a clip is selected on the timeline. Wraps
/// `KadrUI.InspectorPanel` and routes its callbacks back into `ProjectStore`
/// mutations.
@available(iOS 16, macOS 13, visionOS 1, *)
struct InspectorArea: View {

    @ObservedObject var store: ProjectStore

    var body: some View {
        InspectorPanel(
            store.video,
            selectedClipID: Binding(
                get: { store.selectedClipID },
                set: { store.selectedClipID = $0 }
            ),
            onTransform: { id, transform in
                store.applyTransform(id: id, transform)
            },
            onOpacity: { id, opacity in
                store.applyOpacity(id: id, opacity)
            },
            onFilterIntensity: { id, index, value in
                store.applyFilterIntensity(id: id, filterIndex: index, value: value)
            }
        )
        .frame(maxHeight: 320)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
