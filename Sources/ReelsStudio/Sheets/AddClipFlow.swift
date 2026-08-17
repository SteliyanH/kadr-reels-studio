import SwiftUI
import Kadr
import KadrPhotos
#if canImport(Photos)
import Photos
#endif

#if canImport(PhotosUI)

/// View modifier that presents `PhotoPicker` when `isPresented` is true and resolves
/// the picked PHAssets into kadr `Clip` values, appending them to the store. Used by
/// `EditorView` for the `+ Clip` toolbar action.
///
/// Picker selection fires via `pickedItems` binding; an `onChange` watcher kicks off
/// `PhotosClipResolver.clips(from:)` and appends the resolved clips to the project.
/// Resolution failures surface as a console log in v0.1; a v0.1.x patch can wire an
/// alert.
struct AddClipFlow: ViewModifier {

    @Binding var isPresented: Bool
    var store: ProjectStore
    @Environment(ToastCenter.self) private var toasts
    @State private var pickedItems: [PhotoPickerResult] = []
    @State private var isResolving = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PhotoPicker(
                    selection: $pickedItems,
                    configuration: .init(selectionLimit: 0, filter: .any)
                )
                .ignoresSafeArea()
            }
            .onChange(of: pickedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                let items = newItems
                Task { await resolveAndAppend(items) }
            }
            .overlay {
                if isResolving {
                    ResolvingOverlay()
                }
            }
    }

    @MainActor
    private func resolveAndAppend(_ items: [PhotoPickerResult]) async {
        isResolving = true
        defer {
            isResolving = false
            pickedItems = []
        }
        do {
            let clips = try await PhotosClipResolver.clips(from: items)
            store.append(clips: clips)
        } catch {
            toasts.show(.transient(
                error,
                prefix: "Couldn't import \(items.count == 1 ? "clip" : "clips")"
            ))
        }
    }
}

extension View {
    /// Convenience: attach the ``AddClipFlow`` modifier.
    func addClipFlow(isPresented: Binding<Bool>, store: ProjectStore) -> some View {
        modifier(AddClipFlow(isPresented: isPresented, store: store))
    }
}

/// Loading overlay shown while `clips(from:)` is in flight. Dimmed background +
/// progress indicator + label.
private struct ResolvingOverlay: View {
    @Environment(\.reelPalette) private var palette

    var body: some View {
        ZStack {
            // v0.8 Tier 2 — the modal scrim is the approved design's 55%
            // black over the live editor, not an ad-hoc 40%.
            Reel.stageInk.opacity(Reel.scrimOpacity).ignoresSafeArea()
            VStack(spacing: Reel.Space.s3) {
                ProgressView()
                    .controlSize(.large)
                Text("Importing clips…")
                    .font(Reel.Typography.body)
                    .foregroundStyle(palette.text)
            }
            .padding(Reel.Space.s6)
            // Nothing floats: the card is a flat surface block, square.
            .background(palette.surface)
        }
    }
}

#endif

// MARK: - Sheet chrome (v0.8 Tier 5a)
//
// Every bottom sheet in the app wears the same chrome, so it is stated once
// here rather than eleven times: square top corners, a 36×5 grabber, an `h3`
// title over a 2pt rule, the print ground, and `.lg` elevation.
//
// It lives in this file because `AddClipFlow.swift` is already the `Sheets/`
// group's home for sheet-adjacent `View` extensions rather than for a sheet of
// its own, and because the project's Xcode target enumerates files explicitly —
// a new file would need `xcodegen generate`, which is out of this mission's
// lane. Deliberately outside the `#if canImport(PhotosUI)` block above: the
// chrome has nothing to do with the photo picker.

/// The sheet grabber. The design draws a square 36×5 bar;
/// `presentationDragIndicator` draws a system capsule that can't be squared
/// off or retinted, so the app draws its own and hides that one.
struct ReelSheetGrabber: View {

    @Environment(\.reelPalette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.divider)
            .frame(
                width: Reel.sheetGrabberWidth,
                height: Reel.sheetGrabberHeight
            )
            .frame(maxWidth: .infinity)
            .padding(.top, Reel.Space.s2)
            .accessibilityHidden(true)
    }
}

/// A sheet's header band: grabber, `h3` title flush left, trailing actions,
/// and the 2pt rule that separates it from the body.
///
/// `title` is a `LocalizedStringKey`, not a `String`, on purpose — `Text(_:)`
/// only routes through `Localizable.strings` for the key overload, and a
/// `String` parameter would silently pick the verbatim one.
struct ReelSheetHeader<Actions: View>: View {

    let title: LocalizedStringKey
    let actions: Actions

    init(_ title: LocalizedStringKey, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            ReelSheetGrabber()
            HStack(alignment: .firstTextBaseline, spacing: Reel.Space.s3) {
                Text(title)
                    .reelHeading(Reel.Typography.h3)
                    // `.navigationTitle` gave the sheet titles the heading
                    // trait for free — that's what put them in VoiceOver's
                    // heading rotor, and drawing our own title band dropped
                    // it. Restated here so every sheet using this header gets
                    // it back at once.
                    .accessibilityAddTraits(.isHeader)
                actions
            }
            .padding(.horizontal, Reel.Space.s4)
            .padding(.top, Reel.Space.s2)
            .padding(.bottom, Reel.Space.s3)
        }
        .reelRule()
    }
}

extension View {

    /// The bottom-sheet chrome: print ground, square corners, `.lg` elevation,
    /// and the design's documented detent.
    ///
    /// - Parameter detent: the fraction of the screen the sheet occupies —
    ///   `Reel.SheetDetent.*` for the four sheets the design documents.
    func reelSheet(_ detent: CGFloat) -> some View {
        reelSheet(detents: [.fraction(detent)])
    }

    /// The same chrome for a sheet the design doesn't give a fixed height —
    /// a full-height editor, or one that needs a second stop.
    func reelSheet(detents: Set<PresentationDetent>) -> some View {
        modifier(ReelSheetChrome(detents: detents))
    }
}

private struct ReelSheetChrome: ViewModifier {

    let detents: Set<PresentationDetent>

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Sheets are chrome; chrome is the print ground.
            .reelSurface(.print)
            .reelElevation(.lg)
            .presentationDetents(detents)
            // The app draws the grabber itself — see `ReelSheetGrabber`.
            .presentationDragIndicator(.hidden)
            // Radius is zero everywhere, including the two corners UIKit
            // rounds for a sheet by default.
            .presentationCornerRadius(Reel.Radius.lg)
            .presentationBackground(ReelPalette.print.bg)
    }
}
