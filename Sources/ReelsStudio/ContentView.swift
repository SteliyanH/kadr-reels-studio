import SwiftUI
import Kadr
import KadrUI

/// Placeholder root view. Tier 1 replaces this with `EditorView` — preview +
/// timeline + toolbar wired against `ProjectStore`.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Reels Studio")
                .font(.largeTitle.bold())
            Text("Editor walking skeleton lands in Tier 1.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Kadr · KadrUI · KadrCaptions · KadrPhotos")
                .font(.footnote.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
