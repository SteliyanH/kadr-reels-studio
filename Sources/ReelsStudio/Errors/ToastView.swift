import SwiftUI

/// Top-anchored banner rendered above the host content. Tap to dismiss
/// early; auto-dismisses after ``ToastCenter/transientDuration`` seconds.
struct ToastView: View {

    let toast: TransientToast
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(toast.message)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            if let detail = toast.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal, 16)
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

    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = center.current {
                    ToastView(toast: toast) {
                        center.dismissTransient()
                    }
                    .padding(.top, 8)
                    .zIndex(100)
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
    @ObservedObject var center: ToastCenter

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(error.message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button("Cancel", role: .cancel) {
                    center.dismissResumable()
                }
                .buttonStyle(.bordered)
                Button("Retry") {
                    let retry = error.retry
                    center.dismissResumable()
                    Task { await retry() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 32)
        .presentationDetents([.medium])
    }
}
