import SwiftUI
import Kadr
import KadrUI

/// Inspector panel — slides in when a clip is selected on the timeline.
/// Wraps `KadrUI.InspectorPanel` for clip-property sliders, plus a "Speed
/// curve…" affordance that pushes ``SpeedCurveSheet`` for `VideoClip`
/// selections (the editor's log-scaled multiplier axis needs room a row
/// can't give).
///
/// v0.8 Tier 5b — the band is the design's `surfaceRaised` block, and the
/// "Speed curve…" row (the one row this file draws) takes the design's
/// treatment: a 2pt rule above it, an accent glyph, the value at `textMuted`,
/// a chevron.
///
/// **Not reachable.** The design's Transform / Opacity / Filters segmented
/// control has nothing to drive: `InspectorPanel` renders all three sections
/// in one scroll view and exposes no section selection, so an app-side
/// `ModernistSegmentedControl` here would be inert chrome — a lie, and new
/// behaviour besides. Reported as a gap. The panel's own section headers,
/// slider track, thumb and row metrics are likewise upstream literals.
struct InspectorArea: View {

    var store: ProjectStore
    @State private var showSpeedCurveSheet = false
    @Environment(\.modernistPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
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
            if isSelectedAVideoClip {
                speedCurveRow
            }
        }
        .frame(maxHeight: Modernist.inspectorMaxHeight)
        // v0.8 Tier 2 — nothing floats in this system, so the blur is off-
        // message; the panel is a flat raised surface on the studio ground.
        .background(palette.surfaceRaised)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clip inspector")
        .sheet(isPresented: $showSpeedCurveSheet) {
            if let id = store.selectedClipID {
                SpeedCurveSheet(store: store, clipID: id)
            }
        }
    }

    private var isSelectedAVideoClip: Bool {
        guard let id = store.selectedClipID else { return false }
        return store.project.clips.contains { $0.clipID == id && $0 is VideoClip }
    }

    @ViewBuilder
    private var speedCurveRow: some View {
        Button { showSpeedCurveSheet = true } label: {
            HStack(spacing: Modernist.Space.s2) {
                Image(systemName: "speedometer")
                    .foregroundStyle(palette.accent)
                Text("Speed curve…")
                    .font(Modernist.Typography.body)
                    .foregroundStyle(palette.text)
                Spacer()
                if hasSpeedCurve {
                    Text("Custom")
                        .font(Modernist.Typography.caption)
                        .foregroundStyle(palette.textMuted)
                }
                Image(systemName: "chevron.right")
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.textMuted)
            }
            .padding(.horizontal, Modernist.Space.s4)
            .frame(minHeight: Modernist.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The one rule in this band: it separates the panel's parameter rows
        // from the row that leaves the band entirely for a sheet.
        .modernistRule(.top)
    }

    private var hasSpeedCurve: Bool {
        guard let id = store.selectedClipID else { return false }
        return store.project.clips
            .compactMap { $0 as? VideoClip }
            .first { $0.clipID == id }?
            .speedCurve != nil
    }
}
