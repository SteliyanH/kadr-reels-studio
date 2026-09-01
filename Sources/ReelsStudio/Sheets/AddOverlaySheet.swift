import SwiftUI
import Kadr
import KadrPhotos
#if canImport(Photos)
import Photos
#endif

/// Three-tab sheet for adding overlays — **Text** (live editor with style
/// controls), **Image** (photo picker → ``Kadr/ImageOverlay``),
/// **Sticker** (photo picker → ``Kadr/StickerOverlay``). Closes the v0.1.x
/// deferral that left the sheet text-only.
///
/// Image / sticker source uses kadr-photos' `PhotoPicker`; the picked
/// `PHAsset` resolves through `PhotosClipResolver.image(asset:duration:...)`
/// and the resulting `PlatformImage` powers the overlay constructor.
///
/// v0.8 Tier 5a rebuilds the chrome to the approved design (Screens §7):
/// canvas preview with a 2pt dashed selection frame, a Modernist segmented
/// control, a text row on `surfaceRaised`, and SIZE / WEIGHT / COLOR blocks.
/// Every mutation is the one v0.2 shipped.
struct AddOverlaySheet: View {

    var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts

    @State private var selectedTab: Tab = .text
    @Environment(\.reelPalette) private var palette

    enum Tab: Hashable { case text, image, sticker }

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetHeader("Add Overlay") {
                Button("Cancel") { dismiss() }
                    .buttonStyle(ReelGhostButtonStyle())
            }

            ReelSegmentedControl(
                options: [
                    (Tab.text, NSLocalizedString("Text", comment: "Text overlay tab")),
                    (Tab.image, NSLocalizedString("Image", comment: "Image overlay tab")),
                    (Tab.sticker, NSLocalizedString("Sticker", comment: "Sticker overlay tab")),
                ],
                selection: $selectedTab
            )
            .padding(Reel.Space.s4)

            switch selectedTab {
            case .text:    TextOverlayTab(store: store, dismiss: dismiss)
            case .image:   PhotoOverlayTab(store: store, kind: .image, dismiss: dismiss)
            case .sticker: PhotoOverlayTab(store: store, kind: .sticker, dismiss: dismiss)
            }
        }
        .reelSheet(Reel.SheetDetent.addOverlay)
    }
}

// MARK: - Text overlay content model
//
// Hoisted out of the private tab view so the two things that are *contract*
// rather than layout — the default colour and the swatch list — can be pinned
// by a test.

extension AddOverlaySheet {

    /// The colour a new text overlay starts at.
    ///
    /// **Content default, not chrome — do not theme.** This value goes into
    /// `TextStyle(color:)` and is baked into the user's exported pixels; the
    /// design system's grounds, surfaces and ramps stop at the app's own
    /// chrome. The Modernist migration briefly moved this to
    /// `Reel.Neutral.n100` (#F8F4F4), which silently changed the colour
    /// of every text overlay authored after it. Literal on purpose.
    static let defaultTextColor: Color = .white

    /// One cell of the COLOR row: the colour, and the name VoiceOver speaks
    /// for it.
    ///
    /// A single array of these rather than two parallel literals indexed by
    /// position — `swatchLabels[index]` would trap the moment the two lists
    /// drifted by one entry, and nothing in the type system said they had to
    /// agree. Now a mismatch can't be written down.
    struct TextColorSwatch: Hashable {
        let color: Color
        let name: String
    }

    /// Decision 4 / the overlay sheet's "COLOR" row — the accent ramp plus
    /// neutrals, not the iOS system palette. `groundText` is the current
    /// ground's ink, so the last cell tracks the surface the sheet is on.
    ///
    /// The names carry WCAG 4.1.2 (Name, Role, Value): the row draws each
    /// swatch as a bare filled `Rectangle`, which has no accessible name of
    /// its own.
    static func textColorSwatches(groundText: Color) -> [TextColorSwatch] {
        [
            TextColorSwatch(
                color: Reel.Neutral.n100,
                name: NSLocalizedString("Off-white", comment: "Overlay text color swatch")
            ),
            TextColorSwatch(
                color: Reel.Neutral.n500,
                name: NSLocalizedString("Mid gray", comment: "Overlay text color swatch")
            ),
            TextColorSwatch(
                color: Reel.Neutral.n900,
                name: NSLocalizedString("Near black", comment: "Overlay text color swatch")
            ),
            TextColorSwatch(
                color: Reel.Accent.a500,
                name: NSLocalizedString("Accent, light", comment: "Overlay text color swatch")
            ),
            TextColorSwatch(
                color: Reel.Accent.a700,
                name: NSLocalizedString("Accent, dark", comment: "Overlay text color swatch")
            ),
            TextColorSwatch(
                color: groundText,
                name: NSLocalizedString("Ground text color", comment: "Overlay text color swatch")
            ),
        ]
    }

    /// The font-size row's quantization, in points. v0.5–v0.7 shipped
    /// `Slider(value:in:step:)` with this step; the drawn slider dropped it
    /// and let `TextStyle.fontSize` persist fractional points that the "56 pt"
    /// readout only rounded for display.
    static let fontSizeStep: Double = 2
}

// MARK: - Text tab

private struct TextOverlayTab: View {

    var store: ProjectStore
    let dismiss: DismissAction

    @State private var text: String = "New text"
    @State private var fontSize: Double = 56
    /// Content default, not chrome — do not theme. See
    /// ``AddOverlaySheet/defaultTextColor``.
    @State private var color: Color = AddOverlaySheet.defaultTextColor
    @State private var weight: TextWeight = .bold

    @Environment(\.reelPalette) private var palette

    /// Square cells; the selected one takes a 2pt ring in `palette.text`. The
    /// eyedropper (`ColorPicker`) stays alongside so arbitrary colours are
    /// still reachable: narrowing the swatches is a style call, removing the
    /// picker would be a functional one.
    private var swatches: [AddOverlaySheet.TextColorSwatch] {
        AddOverlaySheet.textColorSwatches(groundText: palette.text)
    }

    enum TextWeight: String, CaseIterable, Identifiable {
        case regular, medium, bold
        var id: String { rawValue }
        var kadrWeight: TextStyle.Weight {
            switch self {
            case .regular: return .regular
            case .medium:  return .medium
            case .bold:    return .bold
            }
        }
        /// Segment content. The three weight names are typographic
        /// identifiers rather than prose; they read the same everywhere the
        /// Latin scale is used, so they aren't routed through the bundle —
        /// same call the accent ramp's "500 / 600 / 700" makes.
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Reel.Space.s6) {
                canvasPreview
                textRow
                sizeRow
                weightRow
                colorRow
                Button("Add Text Overlay") { addTextOverlay() }
                    .buttonStyle(ReelPrimaryButtonStyle(isBlock: true))
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Reel.Space.s4)
            .padding(.bottom, Reel.Space.s6)
        }
    }

    /// The design's 104×185 stage stand-in: the overlay drawn in place, with a
    /// 2pt dashed selection frame around the text box. Flat `surfaceRaised`
    /// rather than the prototype's gradient — a generated hue is exactly what
    /// the mono scheme forbids.
    @ViewBuilder
    private var canvasPreview: some View {
        ZStack {
            palette.surfaceRaised
            Text(text.isEmpty ? "New text" : text)
                // Not chrome: this renders the overlay at the size and weight
                // the user authored, so it stays off the app's type scale by
                // design.
                .font(.system(size: CGFloat(fontSize), weight: swiftUIWeight))
                .foregroundStyle(color)
                .minimumScaleFactor(0.1)
                .lineLimit(3)
                .padding(.horizontal, Reel.Space.s2)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .strokeBorder(
                            palette.accent,
                            style: StrokeStyle(
                                lineWidth: palette.ruleWidth,
                                dash: [Reel.Space.s1, Reel.Space.s1]
                            )
                        )
                )
        }
        .frame(
            width: Reel.overlayCanvasWidth,
            height: Reel.overlayCanvasHeight
        )
        .overlay(
            Rectangle()
                .strokeBorder(palette.divider, lineWidth: palette.ruleWidth)
        )
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var textRow: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Text").reelLabel()
            HStack(spacing: Reel.Space.s3) {
                Image(systemName: "textformat")
                    .foregroundStyle(palette.textMuted)
                TextField("Caption", text: $text, axis: .vertical)
                    .font(Reel.Typography.body)
                    .lineLimit(1...3)
            }
            .padding(Reel.Space.s3)
            .frame(minHeight: Reel.minHitTarget)
            .background(palette.surfaceRaised)
        }
    }

    @ViewBuilder
    private var sizeRow: some View {
        ReelSlider(
            label: NSLocalizedString("Size", comment: "Overlay text size"),
            value: $fontSize,
            range: 24...96,
            step: AddOverlaySheet.fontSizeStep,
            valueText: "\(Int(fontSize)) pt"
        )
    }

    @ViewBuilder
    private var weightRow: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Weight").reelLabel()
            // Three cells, the active one accent-filled — which is exactly
            // what the segmented control already draws.
            ReelSegmentedControl(
                options: TextWeight.allCases.map { ($0, $0.label) },
                selection: $weight
            )
        }
    }

    @ViewBuilder
    private var colorRow: some View {
        VStack(alignment: .leading, spacing: Reel.Space.s2) {
            Text("Color").reelLabel()
            HStack(spacing: Reel.Space.s2) {
                ForEach(swatches, id: \.name) { swatch in
                    Button {
                        color = swatch.color
                    } label: {
                        Rectangle()
                            .fill(swatch.color)
                            .frame(
                                width: Reel.minHitTarget,
                                height: Reel.minHitTarget
                            )
                            .overlay(
                                Rectangle()
                                    .strokeBorder(
                                        color == swatch.color ? palette.text : palette.divider,
                                        lineWidth: palette.ruleWidth
                                    )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(color == swatch.color ? [.isSelected] : [])
                }
                // The eyedropper cell at the end of the row. Preserved
                // verbatim from v0.5: narrowing the swatches is a style call,
                // removing arbitrary colour would be a functional one.
                ColorPicker("Color", selection: $color)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var swiftUIWeight: Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium:  return .medium
        case .bold:    return .bold
        }
    }

    private func addTextOverlay() {
        let style = TextStyle(
            fontSize: fontSize,
            color: PlatformColor.baked(color),
            alignment: .center,
            weight: weight.kadrWeight
        )
        let overlay = TextOverlay(text, style: style)
            .position(.center)
            .anchor(.center)
        store.append(overlay: overlay)
        dismiss()
    }
}

// MARK: - Image / Sticker tab

private struct PhotoOverlayTab: View {

    enum Kind {
        case image, sticker
        var label: String {
            switch self {
            case .image: return NSLocalizedString("Image Overlay", comment: "Image overlay kind")
            case .sticker: return NSLocalizedString("Sticker", comment: "Sticker overlay kind")
            }
        }
        var iconSystemName: String {
            switch self {
            case .image: return "photo"
            case .sticker: return "face.smiling"
            }
        }
    }

    var store: ProjectStore
    let kind: Kind
    let dismiss: DismissAction
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.reelPalette) private var palette

    @State private var picked: [PhotoPickerResult] = []
    @State private var pickedImage: PlatformImage?
    @State private var isResolving = false
    @State private var showPicker = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Reel.Space.s6) {
                VStack(alignment: .leading, spacing: Reel.Space.s2) {
                    Text("Source").reelLabel()
                    Button {
                        showPicker = true
                    } label: {
                        Label(
                            pickedImage == nil ? "Pick image…" : "Picked",
                            systemImage: kind.iconSystemName
                        )
                    }
                    .buttonStyle(ReelSecondaryButtonStyle(isBlock: true))
                    if let pickedImage {
                        pickedThumbnail(pickedImage)
                    }
                }
                VStack(alignment: .leading, spacing: Reel.Space.s2) {
                    Text("Style").reelLabel()
                    ReelSlider(
                        label: NSLocalizedString("Opacity", comment: "Overlay opacity"),
                        value: $opacity,
                        range: 0...1,
                        valueText: String(format: "%.0f%%", opacity * 100)
                    )
                }
                Button(String(format: NSLocalizedString("overlay.add.kind", comment: "Add <kind>"), kind.label)) {
                    addPhotoOverlay()
                }
                .buttonStyle(ReelPrimaryButtonStyle(isBlock: true))
                .disabled(pickedImage == nil)
            }
            .padding(.horizontal, Reel.Space.s4)
            .padding(.bottom, Reel.Space.s6)
        }
        .overlay {
            if isResolving { ProgressView().controlSize(.large) }
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(
                selection: $picked,
                configuration: .init(selectionLimit: 1, filter: .images)
            )
            .ignoresSafeArea()
        }
        .onChange(of: picked) { _, newValue in
            guard !newValue.isEmpty else { return }
            let items = newValue
            Task { await resolvePicked(items) }
        }
    }

    @ViewBuilder
    private func pickedThumbnail(_ image: PlatformImage) -> some View {
        // Echoes the "Picked" state the Source button's label already speaks;
        // a bitmap `Image` carries no name of its own, so left un-hidden it
        // would read as a bare, undescribed "Image" stop right after that
        // button. Same call `TextOverlayTab.canvasPreview` makes.
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: Reel.overlayCanvasWidth)
            .reelGrayscale()
            .overlay(
                Rectangle()
                    .strokeBorder(palette.divider, lineWidth: palette.ruleWidth)
            )
            .accessibilityHidden(true)
        #else
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: Reel.overlayCanvasWidth)
            .reelGrayscale()
            .overlay(
                Rectangle()
                    .strokeBorder(palette.divider, lineWidth: palette.ruleWidth)
            )
            .accessibilityHidden(true)
        #endif
    }

    @MainActor
    private func resolvePicked(_ items: [PhotoPickerResult]) async {
        isResolving = true
        defer {
            isResolving = false
            picked = []
        }
        do {
            #if canImport(Photos)
            guard let result = items.first,
                  let asset = result.resolveAsset() else {
                toasts.show(.transient(message: "Couldn't resolve picked image"))
                return
            }
            // Use a modest target size — overlays don't need full-resolution
            // PNGs and large embeds bloat the on-disk project file. 1024×1024
            // is plenty for stickers / image overlays at common reel sizes.
            let options = PhotosClipResolver.Options(
                imageTargetSize: .pixels(width: 1024, height: 1024),
                imageContentMode: .aspectFit,
                imageDeliveryMode: .highQualityFormat
            )
            let imageClip = try await PhotosClipResolver.image(
                asset: asset,
                duration: 1.0,
                options: options
            )
            pickedImage = imageClip.image
            #else
            toasts.show(.transient(message: "Photos library unavailable on this platform"))
            #endif
        } catch {
            toasts.show(.transient(error, prefix: "Couldn't import image"))
        }
    }

    private func addPhotoOverlay() {
        guard let image = pickedImage else { return }
        let layerID = LayerID(UUID().uuidString)
        switch kind {
        case .image:
            let overlay = ImageOverlay(image)
                .position(.center)
                .anchor(.center)
                .opacity(opacity)
                .id(layerID)
            store.append(overlay: overlay)
        case .sticker:
            let overlay = StickerOverlay(image)
                .position(.center)
                .anchor(.center)
                .opacity(opacity)
                .id(layerID)
            store.append(overlay: overlay)
        }
        dismiss()
    }
}
