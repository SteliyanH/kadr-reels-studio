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
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddOverlaySheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toasts: ToastCenter

    @State private var selectedTab: Tab = .text

    enum Tab: Hashable { case text, image, sticker }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Kind", selection: $selectedTab) {
                    Text("Text").tag(Tab.text)
                    Text("Image").tag(Tab.image)
                    Text("Sticker").tag(Tab.sticker)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Divider()
                    .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .text:    TextOverlayTab(store: store, dismiss: dismiss)
                    case .image:   PhotoOverlayTab(store: store, kind: .image, dismiss: dismiss)
                    case .sticker: PhotoOverlayTab(store: store, kind: .sticker, dismiss: dismiss)
                    }
                }
            }
            .navigationTitle("Add Overlay")
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Text tab

@available(iOS 16, macOS 13, visionOS 1, *)
private struct TextOverlayTab: View {

    @ObservedObject var store: ProjectStore
    let dismiss: DismissAction

    @State private var text: String = "New text"
    @State private var fontSize: Double = 56
    @State private var color: Color = .white
    @State private var weight: TextWeight = .bold

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
    }

    var body: some View {
        Form {
            Section("Text") {
                TextField("Caption", text: $text, axis: .vertical)
                    .lineLimit(1...3)
            }
            Section("Style") {
                HStack {
                    Text("Size")
                    Slider(value: $fontSize, in: 24...96, step: 2)
                    Text("\(Int(fontSize))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 32, alignment: .trailing)
                }
                Picker("Weight", selection: $weight) {
                    ForEach(TextWeight.allCases) { w in
                        Text(w.rawValue.capitalized).tag(w)
                    }
                }
                ColorPicker("Color", selection: $color)
            }
            Section("Preview") {
                Text(text.isEmpty ? "New text" : text)
                    .font(.system(size: CGFloat(fontSize), weight: swiftUIWeight))
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
            Section {
                Button("Add Text Overlay") {
                    addTextOverlay()
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
            color: PlatformColor(color),
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

@available(iOS 16, macOS 13, visionOS 1, *)
private struct PhotoOverlayTab: View {

    enum Kind {
        case image, sticker
        var label: String {
            switch self {
            case .image: return "Image Overlay"
            case .sticker: return "Sticker"
            }
        }
        var iconSystemName: String {
            switch self {
            case .image: return "photo"
            case .sticker: return "face.smiling"
            }
        }
    }

    @ObservedObject var store: ProjectStore
    let kind: Kind
    let dismiss: DismissAction
    @EnvironmentObject private var toasts: ToastCenter

    @State private var picked: [PhotoPickerResult] = []
    @State private var pickedImage: PlatformImage?
    @State private var isResolving = false
    @State private var showPicker = false
    @State private var opacity: Double = 1.0

    var body: some View {
        Form {
            Section("Source") {
                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Image(systemName: kind.iconSystemName)
                        Text(pickedImage == nil ? "Pick image…" : "Picked")
                    }
                }
                if let pickedImage {
                    pickedThumbnail(pickedImage)
                }
            }
            Section("Style") {
                HStack {
                    Text("Opacity")
                    Slider(value: $opacity, in: 0...1)
                    Text(String(format: "%.0f%%", opacity * 100))
                        .font(.caption.monospacedDigit())
                        .frame(width: 44, alignment: .trailing)
                }
            }
            Section {
                Button("Add \(kind.label)") {
                    addPhotoOverlay()
                }
                .disabled(pickedImage == nil)
            }
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
        .onChange(of: picked) { newValue in
            guard !newValue.isEmpty else { return }
            let items = newValue
            Task { await resolvePicked(items) }
        }
    }

    @ViewBuilder
    private func pickedThumbnail(_ image: PlatformImage) -> some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        #else
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                  let asset = await result.resolveAsset() else {
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

// MARK: - Color bridge (unchanged from v0.2)

#if canImport(UIKit)
import UIKit
extension PlatformColor {
    fileprivate convenience init(_ color: Color) {
        self.init(color)
    }
}
#elseif canImport(AppKit)
import AppKit
extension PlatformColor {
    fileprivate convenience init(_ color: Color) {
        let cg = color.resolve(in: .init()).cgColor
        self.init(cgColor: cg) ?? .white
    }
}
#endif

// MARK: - Inline navigation-bar shim

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
