import SwiftUI
import Kadr

/// Sheet for adding a text overlay to the project. v0.1 ships text-only — sticker
/// / watermark / image overlays are deferred to v0.1.x.
///
/// User edits text + font size + color, taps **Add** → appends a `TextOverlay`
/// centered on the canvas to the store.
@available(iOS 16, macOS 13, visionOS 1, *)
struct AddOverlaySheet: View {

    @ObservedObject var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
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
            }
            .navigationTitle("Add Overlay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addOverlay() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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

    private func addOverlay() {
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

// MARK: - Color bridge

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
