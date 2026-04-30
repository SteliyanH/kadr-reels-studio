import Foundation
import Kadr
import KadrUI
import KadrCaptions
import KadrPhotos

/// Reels Studio — flagship reference app for the kadr ecosystem.
///
/// See [DESIGN.md](https://github.com/SteliyanH/kadr-reels-studio/blob/main/DESIGN.md)
/// for the v0.1 RFC. Public API is deliberately small — this is an example app, not a
/// library. Most types are `internal` to the module.
public enum ReelsStudio {
    /// SemVer-style version string. Bumped on each release.
    public static let version = "0.1.0-dev"
}
