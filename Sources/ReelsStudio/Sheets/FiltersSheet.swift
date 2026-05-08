import SwiftUI
import Kadr

/// Filters sheet — pushed from the two-tier toolbar's `Filters` clip-action
/// button. Lists the selected `VideoClip`'s filter stack with per-filter
/// intensity sliders, swipe-to-delete, and a `+` menu of every filter case
/// kadr exposes. Reorder is deferred — list order matches kadr's render
/// order (declaration order), but the v0.4 surface is tap-to-select, so
/// drag-to-reorder isn't a primitive yet.
@available(iOS 16, macOS 13, visionOS 1, *)
struct FiltersSheet: View {

    @ObservedObject var store: ProjectStore
    let clipID: ClipID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Filters")
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        addMenu
                    }
                }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if let clip = videoClip(matching: clipID) {
            if clip.filters.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(Array(clip.filters.enumerated()), id: \.offset) { index, filter in
                        FilterRow(
                            filter: filter,
                            onIntensityChange: { value in
                                store.applyFilterIntensity(id: clipID, filterIndex: index, value: value)
                            }
                        )
                    }
                    .onDelete { offsets in
                        // Walk from highest to lowest so earlier deletes don't
                        // shift the indices of pending deletes.
                        for index in offsets.sorted(by: >) {
                            store.removeFilter(id: clipID, filterIndex: index)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Clip not available")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.filters")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No filters")
                .font(.headline)
            Text("Add a filter from the menu above.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        } label: {
            Image(systemName: "plus")
        }
    }

    private func videoClip(matching id: ClipID) -> VideoClip? {
        store.project.clips.compactMap { $0 as? VideoClip }.first { $0.clipID == id }
    }
}

// MARK: - Row

@available(iOS 16, macOS 13, visionOS 1, *)
private struct FilterRow: View {
    let filter: Filter
    let onIntensityChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.callout)
                Spacer()
                if let scalar = scalarValue {
                    Text(String(format: "%.2f", scalar))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let scalar = scalarValue, let range = scalarRange {
                Slider(
                    value: Binding(get: { scalar }, set: { onIntensityChange($0) }),
                    in: range
                )
            }
        }
        .padding(.vertical, 4)
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

@available(iOS 16, macOS 13, visionOS 1, *)
private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
