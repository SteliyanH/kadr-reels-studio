import Testing
@testable import ReelsStudio

/// Placeholder for the v0.1 cycle. Real tests land alongside Tier 1+ source files.
struct ReelsStudioTests {

    @Test func moduleBuilds() {
        // Compile-time check that every dependency resolves.
        #expect(ReelsStudio.version.hasPrefix("0.1"))
    }
}
