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
struct TextEffectsSection: View {

    var store: ProjectStore

    var body: some View {
        if let id = store.selectedOverlayID,
           let overlay = store.project.overlays.first(where: { $0.layerID == id }) as? TextOverlay {
            VStack(spacing: 12) {
                strokeSection(id: id, overlay: overlay)
                shadowSection(id: id, overlay: overlay)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Stroke

    @ViewBuilder
    private func strokeSection(id: LayerID, overlay: TextOverlay) -> some View {
        let stroke = overlay.style.stroke
        DisclosureGroup {
            VStack(spacing: 8) {
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
                }
                if let stroke {
                    HStack {
                        Text("Width")
                            .frame(width: 60, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { stroke.width },
                                set: { newWidth in
                                    store.setTextStroke(
                                        id: id,
                                        TextStroke(width: newWidth, color: stroke.color)
                                    )
                                }
                            ),
                            in: 0.5...10
                        )
                        Text(String(format: "%.1f", stroke.width))
                            .font(Modernist.Typography.numeric)
                            .frame(width: 36, alignment: .trailing)
                    }
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
            .padding(.vertical, 4)
        } label: {
            Label("Stroke", systemImage: "circle.dashed")
                .font(Modernist.Typography.bodyEmphasis)
        }
    }

    // MARK: - Shadow

    @ViewBuilder
    private func shadowSection(id: LayerID, overlay: TextOverlay) -> some View {
        let shadow = overlay.style.shadow
        DisclosureGroup {
            VStack(spacing: 8) {
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
                }
                if let shadow {
                    shadowOffsetRow(id: id, shadow: shadow, axis: .horizontal)
                    shadowOffsetRow(id: id, shadow: shadow, axis: .vertical)
                    HStack {
                        Text("Blur")
                            .frame(width: 60, alignment: .leading)
                        Slider(
                            value: Binding(
                                get: { shadow.blur },
                                set: { newBlur in
                                    store.setTextShadow(
                                        id: id,
                                        TextShadow(offset: shadow.offset, blur: newBlur, color: shadow.color)
                                    )
                                }
                            ),
                            in: 0...20
                        )
                        Text(String(format: "%.1f", shadow.blur))
                            .font(Modernist.Typography.numeric)
                            .frame(width: 36, alignment: .trailing)
                    }
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
            .padding(.vertical, 4)
        } label: {
            Label("Shadow", systemImage: "shadow")
                .font(Modernist.Typography.bodyEmphasis)
        }
    }

    private enum ShadowAxis { case horizontal, vertical }

    @ViewBuilder
    private func shadowOffsetRow(id: LayerID, shadow: TextShadow, axis: ShadowAxis) -> some View {
        let label = axis == .horizontal ? "X" : "Y"
        let value = axis == .horizontal ? Double(shadow.offset.width) : Double(shadow.offset.height)
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)
            Slider(
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
                in: -20...20
            )
            Text(String(format: "%.1f", value))
                .font(Modernist.Typography.numeric)
                .frame(width: 36, alignment: .trailing)
        }
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
