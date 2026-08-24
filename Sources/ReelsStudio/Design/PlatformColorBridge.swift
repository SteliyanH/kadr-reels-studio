import SwiftUI
import Kadr

// MARK: - SwiftUI Color → PlatformColor

extension PlatformColor {

    /// A SwiftUI `Color` as the `PlatformColor` kadr bakes into exported
    /// pixels — text styles, sticker tints, chroma keys.
    ///
    /// **Why this exists rather than `PlatformColor(color)` at the call site.**
    /// SwiftUI already vends `UIColor(_ color: Color)`, and three files in this
    /// target had each declared their own file-private
    /// `convenience init(_ color: Color)` with that exact signature. A
    /// file-local declaration shadows the imported one, so the body —
    /// `self.init(color)` — resolved to itself and recursed until the stack
    /// overflowed. The compiler warned on all three ("function call causes an
    /// infinite recursion") and the warnings sat unread.
    ///
    /// Nothing caught it, because the tests never called the shadowed
    /// initialiser: they live in the test target, which has no shadow, and they
    /// rebuilt each `TextStyle` themselves rather than invoking the private
    /// view method that built the real one. `SettingsView` was fine for the
    /// same accidental reason — no shadow in that file.
    ///
    /// A named static cannot be shadowed by an initialiser, and it gives the
    /// tests the *same* entry point the app uses instead of a mirror of it.
    /// Call this; never call `PlatformColor(someColor)` directly.
    /// No `#if canImport(UIKit)` here: SwiftUI vends the initialiser under
    /// both names, and this target builds for iOS only. Each of the three
    /// deleted shadows carried an AppKit branch that had never been compiled,
    /// and two of them recursed as well — dead code cannot be wrong out loud.
    nonisolated static func baked(_ color: Color) -> PlatformColor {
        PlatformColor(color)
    }
}
