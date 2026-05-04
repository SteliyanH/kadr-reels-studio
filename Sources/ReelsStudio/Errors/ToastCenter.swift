import Foundation
import SwiftUI

/// App-wide error / status surfacing. Single instance owned at the
/// ``ReelsStudioApp`` root via ``LibraryHost``; routed into every screen
/// through `.environmentObject(toasts)`.
///
/// **Severity routing** mirrors ``AppError``:
/// - `.transient` → ``current`` toast banner, auto-dismisses after 2s.
/// - `.resumable` → ``resumable`` sheet, blocks the surface until the user
///   retries or cancels.
/// - `.catastrophic` → ``catastrophic`` alert, full-screen, single OK button.
///
/// Only one of each tier is shown at a time. A new toast replaces the
/// in-flight one (the user has already moved past the previous error).
@MainActor
final class ToastCenter: ObservableObject {

    @Published var current: TransientToast?
    @Published var resumable: ResumableError?
    @Published var catastrophic: CatastrophicError?

    private var dismissTask: Task<Void, Never>?

    /// Default auto-dismiss for transient toasts. 2 seconds matches the
    /// CapCut / VN baseline — long enough to read, short enough to not
    /// block the next interaction.
    static let transientDuration: TimeInterval = 2.0

    func show(_ error: AppError) {
        switch error {
        case .transient(let message, let detail):
            showTransient(.init(message: message, detail: detail))
        case .resumable(let message, let retry):
            resumable = .init(message: message, retry: retry)
        case .catastrophic(let message, let detail):
            catastrophic = .init(message: message, detail: detail)
        }
    }

    func showTransient(_ toast: TransientToast) {
        current = toast
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: UInt64(Self.transientDuration * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.current?.id == toast.id else { return }
                self?.current = nil
            }
        }
    }

    func dismissTransient() {
        dismissTask?.cancel()
        current = nil
    }

    func dismissResumable() {
        resumable = nil
    }

    func dismissCatastrophic() {
        catastrophic = nil
    }
}

/// Single transient toast — auto-dismissed.
struct TransientToast: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let detail: String?

    init(message: String, detail: String? = nil) {
        self.id = UUID()
        self.message = message
        self.detail = detail
    }
}

/// Resumable error — sheet stays open until the user retries or cancels.
struct ResumableError: Identifiable {
    let id: UUID
    let message: String
    let retry: @Sendable @MainActor () async -> Void

    init(message: String, retry: @escaping @Sendable @MainActor () async -> Void) {
        self.id = UUID()
        self.message = message
        self.retry = retry
    }
}

/// Catastrophic error — full alert, single OK button.
struct CatastrophicError: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String
    let detail: String?

    init(message: String, detail: String? = nil) {
        self.id = UUID()
        self.message = message
        self.detail = detail
    }
}
