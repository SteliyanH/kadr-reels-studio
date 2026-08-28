import Foundation
import CoreMedia
import CoreGraphics
import Kadr
import KadrPersistence

// MARK: - Persistable project shape

/// On-disk JSON shape for a saved project.
///
/// **v6 hands the composition to `KadrPersistence`.** Versions 1–5 carried a
/// hand-written mirror of kadr's DSL — `VideoClipData`, `TextOverlayData`, and
/// the rest, all still below because old documents must still be readable. That
/// mirror had the failure mode every hand-written mirror has: kadr gains a field,
/// nobody updates the mirror, and *nothing fails*. A field missing from both
/// sides of a round-trip comparison compares equal. It cost this app three
/// fields before anyone noticed, and it was still silently dropping `crop` and
/// `quality` when v6 was written.
///
/// So the composition half of this document is now a ``KadrDocument``, and the
/// package's own completeness guard — a reflective test over kadr's types —
/// fails when kadr grows a field. What stays here is what is genuinely this
/// app's: identity, naming, timestamps, and editor preferences. That split is
/// deliberate; a document format that accretes app-specific fields stops being
/// a document format.
///
/// **Schema versioning.** ``schemaVersion`` is bumped for incompatible shapes.
/// Load-side migration to v6 lives in ``ProjectLibrary``; v1–v5 documents are
/// read through the legacy types below, converted once, and rewritten as v6 on
/// the next save.
struct ProjectDocument: Codable, Identifiable, Sendable, Equatable {

    /// Current persistence schema version.
    ///
    /// **v6 (this release)** replaces the hand-written composition mirror with
    /// `KadrPersistence.KadrDocument`, stored under `composition`, plus
    /// `imageBlobs` for images with no file behind them. The v1–v5 fields are
    /// retained as decode-only legacy and are never written.
    ///
    /// **v5** added text-effect fields on `TextOverlayData` and
    /// `TitleSequenceData` — stroke and drop shadow, mirroring kadr v0.12.
    ///
    /// **v4** added `filterIDs` on `VideoClipData`.
    ///
    /// **v3** added `fixedCenterPlayhead`.
    ///
    /// **v2** added keyframe animations, `speedCurve`, and `ProjectClip.track`.
    public static let currentSchemaVersion: Int = 6

    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var schemaVersion: Int

    // MARK: The composition (v6+)

    /// The composition, in `KadrPersistence`'s format. `nil` only on a v1–v5
    /// document that has been decoded but not yet migrated.
    public var composition: KadrDocument?

    /// PNG payloads for `png:` image tokens — images with no file behind them,
    /// such as synthesised swatches. Images that live on disk are referenced by
    /// `file:` token and carry no bytes here. See ``ProjectImageStore``.
    public var imageBlobs: [String: Data]?

    // MARK: Editor preferences (all versions)

    /// Timeline pinch-zoom state, persisted per project. `nil` = auto fit-to-width.
    public var zoomPixelsPerSecond: Double?

    /// Per-project opt-in for kadr-ui's `TimelineView.fixedCenterPlayhead(_:)`.
    /// `nil` on older documents; the runtime falls back to `true`.
    public var fixedCenterPlayhead: Bool?

    /// Per-project accent color as `#RRGGBB(AA)` hex. `nil` = system tint.
    public var accentColorHex: String?

    // MARK: Legacy composition (v1–v5, decode-only)

    /// The v1–v5 hand-written mirror. Read when migrating an old document and
    /// never written: ``toDocument(inheriting:name:)`` always emits v6.
    public var legacyClips: [ProjectClip]?
    public var legacyOverlays: [ProjectOverlay]?
    public var legacyAudioTracks: [ProjectAudioTrack]?
    public var legacyCaptions: [ProjectCaption]?
    public var legacyPreset: ProjectPreset?

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, modifiedAt, schemaVersion
        case composition, imageBlobs
        case zoomPixelsPerSecond, fixedCenterPlayhead, accentColorHex
        // The legacy payload keeps its original key names, because that is what
        // is on disk in every document written before v6.
        case legacyClips = "clips"
        case legacyOverlays = "overlays"
        case legacyAudioTracks = "audioTracks"
        case legacyCaptions = "captions"
        case legacyPreset = "preset"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        schemaVersion: Int = ProjectDocument.currentSchemaVersion,
        composition: KadrDocument? = nil,
        imageBlobs: [String: Data]? = nil,
        zoomPixelsPerSecond: Double? = nil,
        fixedCenterPlayhead: Bool? = nil,
        accentColorHex: String? = nil,
        legacyClips: [ProjectClip]? = nil,
        legacyOverlays: [ProjectOverlay]? = nil,
        legacyAudioTracks: [ProjectAudioTrack]? = nil,
        legacyCaptions: [ProjectCaption]? = nil,
        legacyPreset: ProjectPreset? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.schemaVersion = schemaVersion
        self.composition = composition
        self.imageBlobs = imageBlobs
        self.zoomPixelsPerSecond = zoomPixelsPerSecond
        self.fixedCenterPlayhead = fixedCenterPlayhead
        self.accentColorHex = accentColorHex
        self.legacyClips = legacyClips
        self.legacyOverlays = legacyOverlays
        self.legacyAudioTracks = legacyAudioTracks
        self.legacyCaptions = legacyCaptions
        self.legacyPreset = legacyPreset
    }

    // MARK: Convenience

    /// The composition's clips, or an empty array. For list rows and thumbnails,
    /// which read the persisted shape without building a `Video`.
    public var compositionClips: [KadrPersistence.ClipData] {
        composition?.video.clips ?? []
    }

    /// Whether this document still needs migrating to v6.
    public var needsMigration: Bool {
        composition == nil && schemaVersion < 6
    }
}

// MARK: - Clip sumtype

/// Sumtype mirror of kadr's `any Clip`. v0.3 adds `.track` for `Kadr.Track {}`
/// blocks — the recursive `clips: [ProjectClip]` payload survives Swift's
/// enum recursion through arrays without needing `indirect`.
enum ProjectClip: Codable, Sendable, Equatable {
    case video(VideoClipData)
    case image(ImageClipData)
    case title(TitleSequenceData)
    case transition(TransitionData)
    case track(TrackData)
}

struct VideoClipData: Codable, Sendable, Equatable {
    public var clipID: String?
    public var url: URL
    public var trimStartSeconds: Double?
    public var trimDurationSeconds: Double?
    public var isReversed: Bool
    public var isMuted: Bool
    public var speedRate: Double
    public var opacity: Double?
    /// Per-clip filters applied in order.
    public var filters: [ProjectFilter]
    /// Stable per-filter identifiers, parallel to ``filters``. Mirrors
    /// kadr v0.11's `VideoClip.filterIDs`. Outer optional handles v1 / v2 / v3
    /// migration (missing key → nil); on load the bridge currently falls
    /// back to kadr's auto-generated ids (a public seam to inject persisted
    /// ids on construction is filed as a follow-up against kadr — until then
    /// these round-trip but don't survive across cold launches as the same
    /// identifier). v4.
    public var filterIDs: [String]?
    /// Position / rotation / scale / anchor — round-trips inspector edits.
    public var transform: ProjectTransform?
    /// Keyframe animation driving ``transform``. v2.
    public var transformAnimation: ProjectAnimation<ProjectTransform>?
    /// Keyframe animation driving ``opacity``. v2.
    public var opacityAnimation: ProjectAnimation<Double>?
    /// Optional animation per filter, parallel to ``filters``. Drives the
    /// scalar of each filter at the same index. Outer optional handles v1
    /// → v2 migration (missing key → nil); inner optional means a specific
    /// filter is static. v2.
    public var filterAnimations: [ProjectAnimation<Double>?]?
    /// Speed curve (per-clip-time speed multiplier). Mutually exclusive
    /// with a non-1.0 ``speedRate`` — the engine prefers the curve when
    /// both are set. v2.
    public var speedCurve: ProjectAnimation<Double>?

    public init(
        clipID: String? = nil,
        url: URL,
        trimStartSeconds: Double? = nil,
        trimDurationSeconds: Double? = nil,
        isReversed: Bool = false,
        isMuted: Bool = false,
        speedRate: Double = 1.0,
        opacity: Double? = nil,
        filters: [ProjectFilter] = [],
        filterIDs: [String]? = nil,
        transform: ProjectTransform? = nil,
        transformAnimation: ProjectAnimation<ProjectTransform>? = nil,
        opacityAnimation: ProjectAnimation<Double>? = nil,
        filterAnimations: [ProjectAnimation<Double>?]? = nil,
        speedCurve: ProjectAnimation<Double>? = nil
    ) {
        self.clipID = clipID
        self.url = url
        self.trimStartSeconds = trimStartSeconds
        self.trimDurationSeconds = trimDurationSeconds
        self.isReversed = isReversed
        self.isMuted = isMuted
        self.speedRate = speedRate
        self.opacity = opacity
        self.filters = filters
        self.filterIDs = filterIDs
        self.transform = transform
        self.transformAnimation = transformAnimation
        self.opacityAnimation = opacityAnimation
        self.filterAnimations = filterAnimations
        self.speedCurve = speedCurve
    }
}

struct TrackData: Codable, Sendable, Equatable {
    /// `Track {}` blocks always have a start time on the composition
    /// timeline (kadr defaults to `.zero` for the parameter-less init).
    public var startTimeSeconds: Double
    public var name: String?
    public var opacityFactor: Double
    public var clips: [ProjectClip]

    public init(
        startTimeSeconds: Double = 0,
        name: String? = nil,
        opacityFactor: Double = 1.0,
        clips: [ProjectClip] = []
    ) {
        self.startTimeSeconds = startTimeSeconds
        self.name = name
        self.opacityFactor = opacityFactor
        self.clips = clips
    }
}

struct ImageClipData: Codable, Sendable, Equatable {
    public var clipID: String?
    /// Either a file URL (photo-library imports) or embedded PNG data
    /// (synthesized swatches, shareable across devices).
    public var storage: ImageStorage
    public var durationSeconds: Double
    public var opacity: Double?
    public var transform: ProjectTransform?
    public var transformAnimation: ProjectAnimation<ProjectTransform>?
    public var opacityAnimation: ProjectAnimation<Double>?

    public init(
        clipID: String? = nil,
        storage: ImageStorage,
        durationSeconds: Double,
        opacity: Double? = nil,
        transform: ProjectTransform? = nil,
        transformAnimation: ProjectAnimation<ProjectTransform>? = nil,
        opacityAnimation: ProjectAnimation<Double>? = nil
    ) {
        self.clipID = clipID
        self.storage = storage
        self.durationSeconds = durationSeconds
        self.opacity = opacity
        self.transform = transform
        self.transformAnimation = transformAnimation
        self.opacityAnimation = opacityAnimation
    }
}

enum ImageStorage: Codable, Sendable, Equatable {
    case url(URL)
    /// Base64-encoded PNG. Reasonable for the demo swatches (~10 KB each)
    /// and for any bundled image; not appropriate for full-resolution photos.
    case embeddedPNG(Data)
}

struct TitleSequenceData: Codable, Sendable, Equatable {
    public var clipID: String?
    public var text: String
    public var fontSize: Double
    public var fontWeight: ProjectFontWeight
    /// `#RRGGBB` (or `#RRGGBBAA`) hex. `nil` keeps the platform default
    /// (white).
    public var colorHex: String?
    public var alignment: ProjectTextAlignment
    public var durationSeconds: Double
    public var transform: ProjectTransform?

    /// Per-text outline. Width in points, color as hex. `nil` (or width 0)
    /// = no stroke. v5.
    public var strokeWidth: Double?
    public var strokeColorHex: String?

    /// Per-text drop shadow. Offset in points, blur in points, color as hex.
    /// `nil` (any field) = no shadow. v5.
    public var shadowOffsetX: Double?
    public var shadowOffsetY: Double?
    public var shadowBlur: Double?
    public var shadowColorHex: String?

    public init(
        clipID: String? = nil,
        text: String,
        fontSize: Double = 36,
        fontWeight: ProjectFontWeight = .regular,
        colorHex: String? = nil,
        alignment: ProjectTextAlignment = .leading,
        durationSeconds: Double = 2.0,
        transform: ProjectTransform? = nil,
        strokeWidth: Double? = nil,
        strokeColorHex: String? = nil,
        shadowOffsetX: Double? = nil,
        shadowOffsetY: Double? = nil,
        shadowBlur: Double? = nil,
        shadowColorHex: String? = nil
    ) {
        self.clipID = clipID
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.colorHex = colorHex
        self.alignment = alignment
        self.durationSeconds = durationSeconds
        self.transform = transform
        self.strokeWidth = strokeWidth
        self.strokeColorHex = strokeColorHex
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.shadowBlur = shadowBlur
        self.shadowColorHex = shadowColorHex
    }
}

struct TransitionData: Codable, Sendable, Equatable {
    public var kind: TransitionKind
    public var durationSeconds: Double

    public enum TransitionKind: String, Codable, Sendable, Equatable {
        case fade
        case dissolve
    }

    public init(kind: TransitionKind, durationSeconds: Double) {
        self.kind = kind
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Overlay sumtype

enum ProjectOverlay: Codable, Sendable, Equatable {
    case text(TextOverlayData)
    case image(ImageOverlayData)
    case sticker(StickerOverlayData)
}

struct TextOverlayData: Codable, Sendable, Equatable {
    public var layerID: String?
    public var text: String
    public var fontSize: Double
    public var fontWeight: ProjectFontWeight
    public var colorHex: String?
    public var alignment: ProjectTextAlignment
    public var positionX: Double  // normalized 0...1
    public var positionY: Double  // normalized 0...1
    public var anchor: ProjectAnchor
    public var opacity: Double

    /// Outline (width in points, color as hex). `nil` / width 0 = no
    /// stroke; v4 docs decode with both nil so existing overlays render
    /// unchanged. v5.
    public var strokeWidth: Double?
    public var strokeColorHex: String?

    /// Drop shadow (offset in points + Gaussian blur in points + hex color).
    /// All four fields nil = no shadow. v5.
    public var shadowOffsetX: Double?
    public var shadowOffsetY: Double?
    public var shadowBlur: Double?
    public var shadowColorHex: String?

    public init(
        layerID: String? = nil,
        text: String,
        fontSize: Double = 36,
        fontWeight: ProjectFontWeight = .regular,
        colorHex: String? = nil,
        alignment: ProjectTextAlignment = .center,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        anchor: ProjectAnchor = .center,
        opacity: Double = 1.0,
        strokeWidth: Double? = nil,
        strokeColorHex: String? = nil,
        shadowOffsetX: Double? = nil,
        shadowOffsetY: Double? = nil,
        shadowBlur: Double? = nil,
        shadowColorHex: String? = nil
    ) {
        self.layerID = layerID
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.colorHex = colorHex
        self.alignment = alignment
        self.positionX = positionX
        self.positionY = positionY
        self.anchor = anchor
        self.opacity = opacity
        self.strokeWidth = strokeWidth
        self.strokeColorHex = strokeColorHex
        self.shadowOffsetX = shadowOffsetX
        self.shadowOffsetY = shadowOffsetY
        self.shadowBlur = shadowBlur
        self.shadowColorHex = shadowColorHex
    }
}

struct ImageOverlayData: Codable, Sendable, Equatable {
    public var layerID: String?
    public var storage: ImageStorage
    public var positionX: Double
    public var positionY: Double
    public var anchor: ProjectAnchor
    public var opacity: Double

    public init(
        layerID: String? = nil,
        storage: ImageStorage,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        anchor: ProjectAnchor = .center,
        opacity: Double = 1.0
    ) {
        self.layerID = layerID
        self.storage = storage
        self.positionX = positionX
        self.positionY = positionY
        self.anchor = anchor
        self.opacity = opacity
    }
}

struct StickerOverlayData: Codable, Sendable, Equatable {
    public var layerID: String?
    public var storage: ImageStorage
    public var positionX: Double
    public var positionY: Double
    public var anchor: ProjectAnchor
    public var opacity: Double
    public var rotationRadians: Double

    public init(
        layerID: String? = nil,
        storage: ImageStorage,
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        anchor: ProjectAnchor = .center,
        opacity: Double = 1.0,
        rotationRadians: Double = 0
    ) {
        self.layerID = layerID
        self.storage = storage
        self.positionX = positionX
        self.positionY = positionY
        self.anchor = anchor
        self.opacity = opacity
        self.rotationRadians = rotationRadians
    }
}

// MARK: - Audio track

struct ProjectAudioTrack: Codable, Sendable, Equatable {
    public var url: URL
    public var startTimeSeconds: Double?
    public var explicitDurationSeconds: Double?
    public var volume: Double
    public var fadeInSeconds: Double?
    public var fadeOutSeconds: Double?
    public var duckingTargetVolume: Double?
    public var crossfadeDurationSeconds: Double?

    public init(
        url: URL,
        startTimeSeconds: Double? = nil,
        explicitDurationSeconds: Double? = nil,
        volume: Double = 1.0,
        fadeInSeconds: Double? = nil,
        fadeOutSeconds: Double? = nil,
        duckingTargetVolume: Double? = nil,
        crossfadeDurationSeconds: Double? = nil
    ) {
        self.url = url
        self.startTimeSeconds = startTimeSeconds
        self.explicitDurationSeconds = explicitDurationSeconds
        self.volume = volume
        self.fadeInSeconds = fadeInSeconds
        self.fadeOutSeconds = fadeOutSeconds
        self.duckingTargetVolume = duckingTargetVolume
        self.crossfadeDurationSeconds = crossfadeDurationSeconds
    }
}

// MARK: - Caption (mirror of Kadr.Caption — stays Codable-friendly)

struct ProjectCaption: Codable, Sendable, Equatable {
    public var text: String
    public var startSeconds: Double
    public var durationSeconds: Double

    public init(text: String, startSeconds: Double, durationSeconds: Double) {
        self.text = text
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Preset / enum mirrors

enum ProjectPreset: Codable, Sendable, Equatable {
    case auto
    case reelsAndShorts
    case tiktok
    case square
    case cinema
    case custom(width: Int, height: Int, frameRate: Int, codecHEVC: Bool)
}

enum ProjectFontWeight: String, Codable, Sendable, Equatable {
    case regular, medium, bold
}

enum ProjectTextAlignment: String, Codable, Sendable, Equatable {
    case leading, center, trailing
}

enum ProjectAnchor: String, Codable, Sendable, Equatable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight
}

// MARK: - Filter sumtype (v0.2 Tier 1.5)

/// Sumtype mirror of every kadr `Filter` case. Fully round-trippable in v0.2:
/// scalar filters carry their value, `mono` is parameterless, `lut` persists
/// the source `.cube` URL (re-parsed on load), and `chromaKey` persists the
/// target color's RGB components + threshold (the GPU-side cube is rebuilt
/// from those on load via `ChromaKey.init(color:threshold:)`).
enum ProjectFilter: Codable, Sendable, Equatable {
    case brightness(Double)
    case contrast(Double)
    case saturation(Double)
    case exposure(Double)
    case sepia(Double)
    case gaussianBlur(Double)
    case vignette(Double)
    case sharpen(Double)
    case zoomBlur(Double)
    case glow(Double)
    case mono
    /// LUT source `.cube` file URL. Reconstruction calls `LUT(url:)`; if the
    /// file is missing on load, the filter is dropped with a console warning
    /// rather than failing the whole project.
    case lut(url: URL)
    /// Chroma-key target color (RGB in `0...1`) + threshold. Reconstruction
    /// rebuilds the GPU cube via `ChromaKey.init(color: PlatformColor, threshold:)`.
    case chromaKey(r: Double, g: Double, b: Double, threshold: Double)
}

// MARK: - Transform mirror

/// On-disk shape for kadr's `Transform`. `centerX` / `centerY` are normalized
/// `0...1` (matches the renderer's coordinate space and what the inspector
/// emits). Angles in radians.
struct ProjectTransform: Codable, Sendable, Equatable {
    public var centerX: Double
    public var centerY: Double
    public var rotation: Double
    public var scale: Double
    public var anchor: ProjectAnchor

    public init(
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        rotation: Double = 0,
        scale: Double = 1.0,
        anchor: ProjectAnchor = .center
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.rotation = rotation
        self.scale = scale
        self.anchor = anchor
    }
}
