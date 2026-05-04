import Foundation
import CoreMedia
import CoreGraphics
import Kadr

// MARK: - Persistable project shape

/// On-disk JSON shape for a saved project. Decoupled from the in-memory
/// ``Project`` so the persistence schema can evolve without breaking the
/// editor's runtime types — and vice versa.
///
/// **Schema versioning.** ``schemaVersion`` is bumped whenever the on-disk
/// shape changes incompatibly. v0.2 ships at version `1`. The library
/// rejects unknown versions with ``ProjectLibraryError/unsupportedSchema(_:)``
/// rather than silently misinterpreting fields.
struct ProjectDocument: Codable, Identifiable, Sendable, Equatable {

    /// Current persistence schema version. Increment for incompatible changes;
    /// load-side migrations live in ``ProjectLibrary``.
    public static let currentSchemaVersion: Int = 1

    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var schemaVersion: Int
    public var clips: [ProjectClip]
    public var overlays: [ProjectOverlay]
    public var audioTracks: [ProjectAudioTrack]
    public var captions: [ProjectCaption]
    public var preset: ProjectPreset

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        schemaVersion: Int = ProjectDocument.currentSchemaVersion,
        clips: [ProjectClip] = [],
        overlays: [ProjectOverlay] = [],
        audioTracks: [ProjectAudioTrack] = [],
        captions: [ProjectCaption] = [],
        preset: ProjectPreset = .reelsAndShorts
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.schemaVersion = schemaVersion
        self.clips = clips
        self.overlays = overlays
        self.audioTracks = audioTracks
        self.captions = captions
        self.preset = preset
    }
}

// MARK: - Clip sumtype

/// Sumtype mirror of kadr's `any Clip`. v0.2 covers the four kinds the editor
/// actually creates (video / image / title / transition); ``Track`` blocks
/// land in v0.3 alongside the multi-track UI.
enum ProjectClip: Codable, Sendable, Equatable {
    case video(VideoClipData)
    case image(ImageClipData)
    case title(TitleSequenceData)
    case transition(TransitionData)
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
    /// Per-clip filters applied in order. Round-trips every `Filter` case
    /// `InspectorPanel` exposes a slider for. `mono` / `lut` / `chromaKey`
    /// require larger surfaces (LUT data, chroma-key parameters); v0.2
    /// drops them on round-trip with a console warning.
    public var filters: [ProjectFilter]
    /// Position / rotation / scale / anchor — round-trips inspector edits.
    public var transform: ProjectTransform?

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
        transform: ProjectTransform? = nil
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
        self.transform = transform
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

    public init(
        clipID: String? = nil,
        storage: ImageStorage,
        durationSeconds: Double,
        opacity: Double? = nil,
        transform: ProjectTransform? = nil
    ) {
        self.clipID = clipID
        self.storage = storage
        self.durationSeconds = durationSeconds
        self.opacity = opacity
        self.transform = transform
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

    public init(
        clipID: String? = nil,
        text: String,
        fontSize: Double = 36,
        fontWeight: ProjectFontWeight = .regular,
        colorHex: String? = nil,
        alignment: ProjectTextAlignment = .leading,
        durationSeconds: Double = 2.0,
        transform: ProjectTransform? = nil
    ) {
        self.clipID = clipID
        self.text = text
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.colorHex = colorHex
        self.alignment = alignment
        self.durationSeconds = durationSeconds
        self.transform = transform
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
        opacity: Double = 1.0
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
