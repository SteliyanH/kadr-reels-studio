import SwiftUI

/// Top-anchored banner rendered above the host content. Tap to dismiss
/// early; auto-dismisses after ``ToastCenter/transientDuration`` seconds.
struct ToastView: View {

    let toast: TransientToast
    var onTap: (() -> Void)? = nil

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        // v0.8 Tier 3 — the banner is an inverted block: ink ground, ground-
        // coloured type. Same read as the old black-at-85% panel, but stated
        // in palette roles, so it inverts correctly on the studio ground.
        VStack(alignment: .leading, spacing: Modernist.Space.s1) {
            Text(toast.message)
                .font(Modernist.Typography.bodyEmphasis)
                .foregroundStyle(palette.bg)
            if let detail = toast.detail {
                Text(detail)
                    .font(Modernist.Typography.caption)
                    .foregroundStyle(palette.bg.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Modernist.Space.s4)
        .padding(.vertical, Modernist.Space.s3)
        .background(
            RoundedRectangle(cornerRadius: Modernist.Radius.md)
                .fill(palette.text)
        )
        .modernistElevation(.md)
        .padding(.horizontal, Modernist.Space.s4)
        .onTapGesture { onTap?() }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Host modifier

extension View {

    /// Install global error surfacing on this view. Shows transient toasts
    /// at the top, resumable sheets in the middle, catastrophic alerts as
    /// `.alert(...)`. Add at the root view (``ProjectListView`` /
    /// ``LibraryHostView``) so every screen below it inherits surfacing
    /// without re-installing.
    func toastHost(_ center: ToastCenter) -> some View {
        modifier(ToastHostModifier(center: center))
    }
}

private struct ToastHostModifier: ViewModifier {

    @Bindable var center: ToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = center.current {
                    ToastView(toast: toast) {
                        center.dismissTransient()
                    }
                    .padding(.top, Modernist.Space.s2)
                    .zIndex(100)
                    // Collapse the toast content into one VoiceOver element so
                    // message + detail read together instead of as siblings.
                    // `accessibilityLiveRegion` for assertive announcement is
                    // iOS 17+ only — we sit on the iOS 16 floor and accept
                    // that VoiceOver users discover the toast on focus
                    // rather than hear it on appear. Revisit when the
                    // deployment floor moves. v0.5 Tier 2.
                    .accessibilityElement(children: .combine)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: center.current)
            .sheet(item: $center.resumable) { error in
                ResumableErrorSheet(error: error, center: center)
            }
            .alert(
                "Something went wrong",
                isPresented: catastrophicBinding,
                presenting: center.catastrophic
            ) { _ in
                Button("OK", role: .cancel) { center.dismissCatastrophic() }
            } message: { error in
                if let detail = error.detail {
                    Text("\(error.message)\n\n\(detail)")
                } else {
                    Text(error.message)
                }
            }
    }

    private var catastrophicBinding: Binding<Bool> {
        Binding(
            get: { center.catastrophic != nil },
            set: { if !$0 { center.dismissCatastrophic() } }
        )
    }
}

// MARK: - Resumable sheet

private struct ResumableErrorSheet: View {
    let error: ResumableError
    var center: ToastCenter

    @Environment(\.modernistPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Modernist.Space.s4) {
            ModernistSheetGrabber()
            // Decision 4 — no warning role; the accent is what flags a
            // problem in this scheme.
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Modernist.Typography.Glyph.xl, weight: Modernist.Typography.headingWeight))
                .foregroundStyle(palette.accent)
            Text(error.message)
                .modernistHeading(Modernist.Typography.h4)
            HStack(spacing: Modernist.Space.s2) {
                Button("Cancel", role: .cancel) {
                    center.dismissResumable()
                }
                .buttonStyle(ModernistGhostButtonStyle())
                Button("Retry") {
                    let retry = error.retry
                    center.dismissResumable()
                    Task { await retry() }
                }
                .buttonStyle(ModernistPrimaryButtonStyle())
            }
        }
        .padding(Modernist.Space.s4)
        // No documented detent for this one — `.medium` is what v0.5 shipped
        // and the sheet's content hasn't changed size.
        .modernistSheet(detents: [.medium])
    }
}
