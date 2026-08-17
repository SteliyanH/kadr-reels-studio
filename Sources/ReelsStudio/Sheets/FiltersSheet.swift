import SwiftUI
import Kadr

/// Filters sheet — pushed from the two-tier toolbar's `Filters` clip-action
/// button. Lists the selected `VideoClip`'s filter stack with per-filter
/// intensity sliders, swipe-to-delete, and a `+` menu of every filter case
/// kadr exposes. Reorder is deferred — list order matches kadr's render
/// order (declaration order), but the v0.4 surface is tap-to-select, so
/// drag-to-reorder isn't a primitive yet.
///
/// v0.8 Tier 5a wears the app's sheet chrome: grabber, `h3` title, square
/// corners, print ground. Behaviour is v0.4's, untouched.
struct FiltersSheet: View {

    var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reelPalette) private var palette

    /// Drives the Chroma Key sub-sheet. Bound to a Bool because the sheet
    /// itself is parameterless (it reads from `clipID` directly). v0.7 Tier 4.
    @State private var showChromaKey = false

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Filters") {
                addMenu
                Button("Done") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
            }
            content
        }
        .sheet(isPresented: $showChromaKey) {
            ChromaKeySheet(store: store, clipID: clipID)
        }
        .reelSheet(detents: [.fraction(Reel.SheetDetent.layers), .large])
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if let clip = videoClip(matching: clipID) {
            if clip.filters.isEmpty {
                emptyState
            } else {
                // Still a `List`: swipe-to-delete is a `List` primitive, so
                // the design's row block is reached by stripping the list's
                // chrome rather than by dropping the container.
                List {
                    ForEach(Array(clip.filters.enumerated()), id: \.offset) { index, filter in
                        FilterRow(
                            filter: filter,
                            onIntensityChange: { value in
                                store.applyFilterIntensity(id: clipID, filterIndex: index, value: value)
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        // Walk from highest to lowest so earlier deletes don't
                        // shift the indices of pending deletes.
                        for index in offsets.sorted(by: >) {
                            store.removeFilter(id: clipID, filterIndex: index)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            VStack(spacing: Reel.Space.s3) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: Reel.Typography.Glyph.lg, weight: Reel.Typography.headingWeight))
                    .foregroundStyle(palette.textMuted)
                Text("Clip not available")
                    .font(Reel.Typography.h5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: Reel.Space.s3) {
            Image(systemName: "camera.filters")
                .font(.system(size: Reel.Typography.Glyph.xl, weight: Reel.Typography.headingWeight))
                .foregroundStyle(palette.textMuted)
            Text("No filters")
                .font(Reel.Typography.h5)
            Text("Add a filter from the menu above.")
                .font(Reel.Typography.body)
                .foregroundStyle(palette.textMuted)
                .frame(maxWidth: Reel.emptyStateMeasure)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Reel.Space.s4)
    }

    // MARK: - Add menu

    @ViewBuilder
    private var addMenu: some View {
        Menu {
            Button("Brightness") { store.addFilter(id: clipID, .brightness(0)) }
            Button("Contrast")   { store.addFilter(id: clipID, .contrast(1)) }
            Button("Saturation") { store.addFilter(id: clipID, .saturation(1)) }
            Button("Exposure")   { store.addFilter(id: clipID, .exposure(0)) }
            Button("Sepia")      { store.addFilter(id: clipID, .sepia(intensity: 1)) }
            Button("Mono")       { store.addFilter(id: clipID, .mono) }
            Button("Gaussian Blur") { store.addFilter(id: clipID, .gaussianBlur(radius: 10)) }
            Button("Vignette")   { store.addFilter(id: clipID, .vignette(intensity: 1)) }
            Button("Sharpen")    { store.addFilter(id: clipID, .sharpen(amount: 0.4)) }
            Button("Zoom Blur")  { store.addFilter(id: clipID, .zoomBlur(amount: 20)) }
            Button("Glow")       { store.addFilter(id: clipID, .glow(intensity: 1)) }
            // v0.7 Tier 4 — chroma key needs a color picker + threshold,
            // so route through a dedicated sub-sheet instead of inserting
            // straight from the menu.
            Button("Chroma Key…") { showChromaKey = true }
        } label: {
            Image(systemName: "plus")
                .frame(width: Reel.minHitTarget, height: Reel.minHitTarget)
                .background(palette.surface)
                .contentShape(Rectangle())
        }
        // Bare "plus" SF Symbol carried no VoiceOver name at all before this
        // — the header's other button (Done) is a real word, so the menu was
        // the one silent control in the sheet's chrome. Reuses the existing
        // "Add Filter" key (the same phrase the undo stack already shows).
        .accessibilityLabel("Add Filter")
    }

    private func videoClip(matching id: ClipID) -> VideoClip? {
        store.project.clips.compactMap { $0 as? VideoClip }.first { $0.clipID == id }
    }
}

// MARK: - Row

private struct FilterRow: View {
    let filter: Filter
    let onIntensityChange: (Double) -> Void

    @Environment(\.reelPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            if let scalar = scalarValue, let range = scalarRange {
                // The slider ships its own label + readout row, which is
                // exactly the "Scale … 1.24×" shape the design asks for — so
                // the separate title line the `Form` version needed is gone.
                ReelSlider(
                    label: label,
                    value: Binding(get: { scalar }, set: { onIntensityChange($0) }),
                    range: range,
                    valueText: String(format: "%.2f", scalar)
                )
            } else {
                Text(label)
                    .font(Reel.Typography.bodyEmphasis)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Reel.Space.s4)
        .padding(.vertical, Reel.Space.s2)
        .frame(minHeight: Reel.minHitTarget)
        .background(palette.surface)
        .reelRule()
    }

    private var label: String {
        switch filter {
        case .brightness:   return "Brightness"
        case .contrast:     return "Contrast"
        case .saturation:   return "Saturation"
        case .exposure:     return "Exposure"
        case .sepia:        return "Sepia"
        case .mono:         return "Mono"
        case .lut:          return "LUT"
        case .chromaKey:    return "Chroma Key"
        case .gaussianBlur: return "Gaussian Blur"
        case .vignette:     return "Vignette"
        case .sharpen:      return "Sharpen"
        case .zoomBlur:     return "Zoom Blur"
        case .glow:         return "Glow"
        }
    }

    private var scalarValue: Double? {
        switch filter {
        case .brightness(let v):       return v
        case .contrast(let v):         return v
        case .saturation(let v):       return v
        case .exposure(let v):         return v
        case .sepia(let v):            return v
        case .gaussianBlur(let v):     return v
        case .vignette(let v):         return v
        case .sharpen(let v):          return v
        case .zoomBlur(let v):         return v
        case .glow(let v):             return v
        case .mono, .lut, .chromaKey:  return nil
        }
    }

    /// Sensible UI ranges per filter — mirrors what the inspector's slider
    /// already shows for the same scalar. Doesn't have to match the underlying
    /// kernel range exactly; we want the most-useful slice.
    private var scalarRange: ClosedRange<Double>? {
        switch filter {
        case .brightness, .exposure:           return -1.0 ... 1.0
        case .contrast, .saturation:           return 0.0 ... 2.0
        case .sepia, .vignette, .glow:         return 0.0 ... 1.0
        case .gaussianBlur:                    return 0.0 ... 50.0
        case .sharpen:                         return 0.0 ... 2.0
        case .zoomBlur:                        return 0.0 ... 100.0
        case .mono, .lut, .chromaKey:          return nil
        }
    }
}
