import SwiftUI
import Kadr

/// v0.7 Tier 3 — stroke + shadow controls for the currently-selected
/// `TextOverlay`. Sibling to `OverlayInspectorArea` — appended below the
/// upstream `OverlayInspectorPanel` so we don't need a kadr-ui patch to
/// surface these controls. Renders only when the selection is a
/// `TextOverlay`; collapses to nothing otherwise.
///
/// Both stroke and shadow have an "Enable" toggle so clearing them through
/// the UI is a single tap. Wide sliders matching the inspector's existing
/// 0-1 / 0-360 sliders so the layout doesn't feel inconsistent.
///
/// v0.8 Tier 5b — chrome only. These are the one set of inspector parameter
/// rows the app actually draws, so they move onto `ReelSlider` (square
/// 2pt track, square thumb, tabular readout). The two `ColorPicker`s stay
/// functional: a swatch ramp can't express an arbitrary stroke or shadow
/// colour, and narrowing them would be a behaviour change, not a restyle.
struct TextEffectsSection: View {

    var store: ProjectStore
    @Environment(\.reelPalette) private var palette

    var body: some View {
        if let id = store.selectedOverlayID,
           let overlay = store.project.overlays.first(where: { $0.layerID == id }) as? TextOverlay {
            VStack(spacing: Reel.Space.s3) {
                strokeSection(id: id, overlay: overlay)
                shadowSection(id: id, overlay: overlay)
            }
            .padding(.horizontal, Reel.Space.s4)
        }
    }

    // MARK: - Stroke

    @ViewBuilder
    private func strokeSection(id: LayerID, overlay: TextOverlay) -> some View {
        let stroke = overlay.style.stroke
        DisclosureGroup {
            VStack(spacing: Reel.Space.s2) {
                Toggle(isOn: Binding(
                    get: { stroke != nil },
                    set: { enabled in
                        if enabled {
                            store.setTextStroke(id: id, TextStroke(width: 2, color: .black))
                        } else {
                            store.setTextStroke(id: id, nil)
                        }
                    }
                )) {
                    Text("Enable stroke")
                        .font(Reel.Typography.body)
                }
                if let stroke {
                    ReelSlider(
                        label: "Width",
                        value: Binding(
                            get: { stroke.width },
                            set: { newWidth in
                                store.setTextStroke(
                                    id: id,
                                    TextStroke(width: newWidth, color: stroke.color)
                                )
                            }
                        ),
                        range: 0.5...10,
                        valueText: TextEffectsSection.readout(stroke.width)
                    )
                    ColorPicker(
                        "Color",
                        selection: Binding(
                            get: { Color(platform: stroke.color) },
                            set: { newColor in
                                store.setTextStroke(
                                    id: id,
                                    TextStroke(width: stroke.width, color: PlatformColor(newColor))
                                )
                            }
                        ),
                        supportsOpacity: false
                    )
                }
            }
            .padding(.vertical, Reel.Space.s1)
        } label: {
            Label("Stroke", systemImage: "circle.dashed")
                .font(Reel.Typography.bodyEmphasis)
                .foregroundStyle(palette.text)
        }
    }

    // MARK: - Shadow

    @ViewBuilder
    private func shadowSection(id: LayerID, overlay: TextOverlay) -> some View {
        let shadow = overlay.style.shadow
        DisclosureGroup {
            VStack(spacing: Reel.Space.s2) {
                Toggle(isOn: Binding(
                    get: { shadow != nil },
                    set: { enabled in
                        if enabled {
                            store.setTextShadow(id: id, TextShadow())
                        } else {
                            store.setTextShadow(id: id, nil)
                        }
                    }
                )) {
                    Text("Enable shadow")
                        .font(Reel.Typography.body)
                }
                if let shadow {
                    shadowOffsetRow(id: id, shadow: shadow, axis: .horizontal)
                    shadowOffsetRow(id: id, shadow: shadow, axis: .vertical)
                    ReelSlider(
                        label: "Blur",
                        value: Binding(
                            get: { shadow.blur },
                            set: { newBlur in
                                store.setTextShadow(
                                    id: id,
                                    TextShadow(offset: shadow.offset, blur: newBlur, color: shadow.color)
                                )
                            }
                        ),
                        range: 0...20,
                        valueText: TextEffectsSection.readout(shadow.blur)
                    )
                    ColorPicker(
                        "Color",
                        selection: Binding(
                            get: { Color(platform: shadow.color) },
                            set: { newColor in
                                store.setTextShadow(
                                    id: id,
                                    TextShadow(
                                        offset: shadow.offset,
                                        blur: shadow.blur,
                                        color: PlatformColor(newColor)
                                    )
                                )
                            }
                        ),
                        supportsOpacity: true
                    )
                }
            }
            .padding(.vertical, Reel.Space.s1)
        } label: {
            Label("Shadow", systemImage: "shadow")
                .font(Reel.Typography.bodyEmphasis)
                .foregroundStyle(palette.text)
        }
    }

    private enum ShadowAxis { case horizontal, vertical }

    @ViewBuilder
    private func shadowOffsetRow(id: LayerID, shadow: TextShadow, axis: ShadowAxis) -> some View {
        let label = axis == .horizontal ? "X" : "Y"
        let value = axis == .horizontal ? Double(shadow.offset.width) : Double(shadow.offset.height)
        ReelSlider(
            label: label,
            value: Binding(
                get: { value },
                set: { newValue in
                    let newOffset: CGSize
                    switch axis {
                    case .horizontal:
                        newOffset = CGSize(width: newValue, height: shadow.offset.height)
                    case .vertical:
                        newOffset = CGSize(width: shadow.offset.width, height: newValue)
                    }
                    store.setTextShadow(
                        id: id,
                        TextShadow(offset: newOffset, blur: shadow.blur, color: shadow.color)
                    )
                }
            ),
            range: -20...20,
            valueText: TextEffectsSection.readout(value)
        )
    }
}

extension TextEffectsSection {
    /// One-decimal readout for the effect sliders, tabular at the call site.
    /// Same format the rows carried before the restyle — the numbers on
    /// screen are unchanged, only the control drawing them is. Pure for
    /// testability.
    nonisolated static func readout(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - Color bridges

private extension Color {
    init(platform color: PlatformColor) {
        #if canImport(UIKit)
        self.init(uiColor: color)
        #else
        self.init(nsColor: color)
        #endif
    }
}

private extension PlatformColor {
    convenience init(_ color: Color) {
        #if canImport(UIKit)
        self.init(color)
        #else
        // AppKit ColorPicker / SwiftUI bridge: round-trip through CGColor.
        self.init(cgColor: NSColor(color).cgColor) ?? .black
        #endif
    }
}
