import Foundation
import CoreMedia
import CoreGraphics
import Kadr
import KadrUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Document → runtime Project

extension ProjectDocument {

    /// Build the in-memory editor ``Project`` from this persisted document.
    /// Some conversions can fail (e.g. an `ImageStorage.url` whose file no
    /// longer exists, or PNG data that can't be decoded); failures are
    /// swallowed at the clip / overlay level so a single corrupt entry
    /// doesn't take the whole project down. The runtime project's `clips`
    /// / `overlays` arrays will be shorter than the document's in that case.
    func toRuntimeProject() -> Project {
        Project(
            clips: clips.compactMap(ProjectDocument.runtimeClip(from:)),
            overlays: overlays.compactMap(ProjectDocument.runtimeOverlay(from:)),
            audioTracks: audioTracks.map(ProjectDocument.runtimeAudioTrack(from:)),
            captions: captions.map(ProjectDocument.runtimeCaption(from:)),
            preset: ProjectDocument.runtimePreset(from: preset),
            zoom: zoomPixelsPerSecond.map { TimelineZoom(pixelsPerSecond: $0) }
        )
    }

    // MARK: Clip dispatch

    nonisolated static func runtimeClip(from data: ProjectClip) -> (any Clip)? {
        switch data {
        case .video(let v):    return runtimeVideoClip(from: v)
        case .image(let i):    return runtimeImageClip(from: i)
        case .title(let t):    return runtimeTitleSequence(from: t)
        case .transition(let t): return runtimeTransition(from: t)
        case .track(let t):    return runtimeTrack(from: t)
        }
    }

    nonisolated static func runtimeTrack(from data: TrackData) -> Track {
        let inner = data.clips.compactMap(runtimeClip(from:))
        let start = CMTime(seconds: data.startTimeSeconds, preferredTimescale: 600)
        var track = Track(at: start, name: data.name) {
            for c in inner { c }
        }
        if data.opacityFactor != 1.0 {
            track = track.opacity(data.opacityFactor)
        }
        return track
    }

    nonisolated static func runtimeVideoClip(from data: VideoClipData) -> VideoClip {
        var clip = VideoClip(url: data.url)
        if let trimStart = data.trimStartSeconds, let trimDur = data.trimDurationSeconds {
            let range = CMTimeRange(
                start: CMTime(seconds: trimStart, preferredTimescale: 600),
                duration: CMTime(seconds: trimDur, preferredTimescale: 600)
            )
            clip = clip.trimmed(to: range)
        }
        if data.isReversed { clip = clip.reversed() }
        if data.isMuted { clip = clip.muted() }
        // Speed curve takes precedence over flat speedRate (matches kadr's
        // engine behavior). When both persist, prefer the curve.
        if let curve = data.speedCurve {
            clip = clip.speed(curve: runtimeDoubleAnimation(from: curve))
        } else if data.speedRate != 1.0 {
            clip = clip.speed(data.speedRate)
        }
        for (index, filter) in data.filters.enumerated() {
            // `lut` may fail to reload (file moved / deleted) — in that case
            // the filter is dropped silently. The rest of the clip survives.
            guard let restored = runtimeFilter(from: filter) else { continue }
            if let animations = data.filterAnimations,
               index < animations.count,
               let animation = animations[index] {
                clip = clip.filter(restored, animation: runtimeDoubleAnimation(from: animation))
            } else {
                clip = clip.filter(restored)
            }
        }
        if let transformAnim = data.transformAnimation, let transform = data.transform {
            clip = clip.transform(runtimeTransform(from: transform), animation: runtimeTransformAnimation(from: transformAnim))
        } else if let transform = data.transform {
            clip = clip.transform(runtimeTransform(from: transform))
        }
        if let opacityAnim = data.opacityAnimation, let opacity = data.opacity {
            clip = clip.opacity(opacity, animation: runtimeDoubleAnimation(from: opacityAnim))
        } else if let opacity = data.opacity {
            clip = clip.opacity(opacity)
        }
        if let id = data.clipID { clip = clip.id(ClipID(id)) }
        return clip
    }

    nonisolated static func runtimeImageClip(from data: ImageClipData) -> ImageClip? {
        guard let image = platformImage(from: data.storage) else { return nil }
        var clip = ImageClip(image, duration: data.durationSeconds)
        if let transformAnim = data.transformAnimation, let transform = data.transform {
            clip = clip.transform(runtimeTransform(from: transform), animation: runtimeTransformAnimation(from: transformAnim))
        } else if let transform = data.transform {
            clip = clip.transform(runtimeTransform(from: transform))
        }
        if let opacityAnim = data.opacityAnimation, let opacity = data.opacity {
            clip = clip.opacity(opacity, animation: runtimeDoubleAnimation(from: opacityAnim))
        } else if let opacity = data.opacity {
            clip = clip.opacity(opacity)
        }
        if let id = data.clipID { clip = clip.id(ClipID(id)) }
        return clip
    }

    nonisolated static func runtimeTitleSequence(from data: TitleSequenceData) -> TitleSequence {
        let style = TextStyle(
            fontSize: data.fontSize,
            color: platformColor(forHex: data.colorHex) ?? .white,
            alignment: textAlignment(from: data.alignment),
            weight: fontWeight(from: data.fontWeight)
        )
        var title = TitleSequence(
            data.text,
            duration: CMTime(seconds: data.durationSeconds, preferredTimescale: 600),
            style: style
        )
        if let transform = data.transform {
            title = title.transform(runtimeTransform(from: transform))
        }
        if let id = data.clipID { title = title.id(ClipID(id)) }
        return title
    }

    // MARK: Filter / Transform reconstruction

    /// Reconstruct a kadr `Filter` from its persisted form. `lut` returns
    /// `nil` when the source `.cube` file is missing or unreadable — the
    /// caller drops the filter and continues. Other cases never fail.
    nonisolated static func runtimeFilter(from data: ProjectFilter) -> Filter? {
        switch data {
        case .brightness(let v):    return .brightness(v)
        case .contrast(let v):      return .contrast(v)
        case .saturation(let v):    return .saturation(v)
        case .exposure(let v):      return .exposure(v)
        case .sepia(let v):         return .sepia(intensity: v)
        case .gaussianBlur(let v):  return .gaussianBlur(radius: v)
        case .vignette(let v):      return .vignette(intensity: v)
        case .sharpen(let v):       return .sharpen(amount: v)
        case .zoomBlur(let v):      return .zoomBlur(amount: v)
        case .glow(let v):          return .glow(intensity: v)
        case .mono:                 return .mono
        case .lut(let url):
            guard let lut = try? LUT(url: url) else { return nil }
            return .lut(lut)
        case .chromaKey(let r, let g, let b, let threshold):
            #if canImport(UIKit)
            let color = PlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
            #else
            let color = PlatformColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
            #endif
            return .chromaKey(ChromaKey(color: color, threshold: threshold))
        }
    }

    nonisolated static func runtimeTransform(from data: ProjectTransform) -> Transform {
        Transform(
            center: .normalized(x: data.centerX, y: data.centerY),
            rotation: data.rotation,
            scale: data.scale,
            anchor: anchor(from: data.anchor)
        )
    }

    nonisolated static func runtimeTransition(from data: TransitionData) -> Kadr.Transition {
        let dur = data.durationSeconds
        switch data.kind {
        case .fade:     return .fade(duration: dur)
        case .dissolve: return .dissolve(duration: dur)
        }
    }

    // MARK: Overlay dispatch

    nonisolated static func runtimeOverlay(from data: ProjectOverlay) -> (any Overlay)? {
        switch data {
        case .text(let t):    return runtimeTextOverlay(from: t)
        case .image(let i):   return runtimeImageOverlay(from: i)
        case .sticker(let s): return runtimeStickerOverlay(from: s)
        }
    }

    nonisolated static func runtimeTextOverlay(from data: TextOverlayData) -> TextOverlay {
        let style = TextStyle(
            fontSize: data.fontSize,
            color: platformColor(forHex: data.colorHex) ?? .white,
            alignment: textAlignment(from: data.alignment),
            weight: fontWeight(from: data.fontWeight)
        )
        var overlay = TextOverlay(data.text, style: style)
            .position(.normalized(x: data.positionX, y: data.positionY))
            .anchor(anchor(from: data.anchor))
            .opacity(data.opacity)
        if let id = data.layerID { overlay = overlay.id(LayerID(id)) }
        return overlay
    }

    nonisolated static func runtimeImageOverlay(from data: ImageOverlayData) -> ImageOverlay? {
        guard let image = platformImage(from: data.storage) else { return nil }
        var overlay = ImageOverlay(image)
            .position(.normalized(x: data.positionX, y: data.positionY))
            .anchor(anchor(from: data.anchor))
            .opacity(data.opacity)
        if let id = data.layerID { overlay = overlay.id(LayerID(id)) }
        return overlay
    }

    nonisolated static func runtimeStickerOverlay(from data: StickerOverlayData) -> StickerOverlay? {
        guard let image = platformImage(from: data.storage) else { return nil }
        var sticker = StickerOverlay(image)
            .position(.normalized(x: data.positionX, y: data.positionY))
            .anchor(anchor(from: data.anchor))
            .opacity(data.opacity)
            .rotation(data.rotationRadians)
        if let id = data.layerID { sticker = sticker.id(LayerID(id)) }
        return sticker
    }

    // MARK: Audio / caption / preset

    nonisolated static func runtimeAudioTrack(from data: ProjectAudioTrack) -> AudioTrack {
        var track = AudioTrack(url: data.url).volume(data.volume)
        if let dur = data.explicitDurationSeconds {
            track = track.duration(dur)
        }
        if let start = data.startTimeSeconds {
            track = track.at(time: start)
        }
        if let fadeIn = data.fadeInSeconds { track = track.fadeIn(fadeIn) }
        if let fadeOut = data.fadeOutSeconds { track = track.fadeOut(fadeOut) }
        if let duck = data.duckingTargetVolume { track = track.ducking(duck) }
        if let cf = data.crossfadeDurationSeconds { track = track.crossfade(cf) }
        return track
    }

    nonisolated static func runtimeCaption(from data: ProjectCaption) -> Caption {
        Caption(
            text: data.text,
            timeRange: CMTimeRange(
                start: CMTime(seconds: data.startSeconds, preferredTimescale: 600),
                duration: CMTime(seconds: data.durationSeconds, preferredTimescale: 600)
            )
        )
    }

    nonisolated static func runtimePreset(from data: ProjectPreset) -> Preset {
        switch data {
        case .auto:           return .auto
        case .reelsAndShorts: return .reelsAndShorts
        case .tiktok:         return .tiktok
        case .square:         return .square
        case .cinema:         return .cinema
        case .custom(let w, let h, let fps, let hevc):
            return .custom(width: w, height: h, frameRate: fps, codec: hevc ? .hevc : .h264)
        }
    }
}

// MARK: - runtime Project → Document

extension Project {

    /// Encode the runtime project into a persistable document. Existing
    /// document identity (`id` / `createdAt` / `name`) is preserved by
    /// passing `inheriting:`; pass `nil` for a fresh document.
    func toDocument(
        inheriting existing: ProjectDocument? = nil,
        name: String = "Untitled"
    ) -> ProjectDocument {
        ProjectDocument(
            id: existing?.id ?? UUID(),
            name: existing?.name ?? name,
            createdAt: existing?.createdAt ?? Date(),
            modifiedAt: Date(),
            schemaVersion: ProjectDocument.currentSchemaVersion,
            clips: clips.compactMap(ProjectDocument.documentClip(from:)),
            overlays: overlays.compactMap(ProjectDocument.documentOverlay(from:)),
            audioTracks: audioTracks.map(ProjectDocument.documentAudioTrack(from:)),
            captions: captions.map(ProjectDocument.documentCaption(from:)),
            preset: ProjectDocument.documentPreset(from: preset),
            zoomPixelsPerSecond: zoom?.pixelsPerSecond
        )
    }
}

extension ProjectDocument {

    nonisolated static func documentClip(from clip: any Clip) -> ProjectClip? {
        if let video = clip as? VideoClip {
            return .video(documentVideoClip(from: video))
        }
        if let image = clip as? ImageClip {
            guard let storage = imageStorage(from: image.image) else { return nil }
            return .image(ImageClipData(
                clipID: image.clipID?.rawValue,
                storage: storage,
                durationSeconds: CMTimeGetSeconds(image.duration),
                opacity: image.opacity,
                transform: image.transform.map(documentTransform(from:)),
                transformAnimation: image.transformAnimation.map(documentTransformAnimation(from:)),
                opacityAnimation: image.opacityAnimation.map(documentDoubleAnimation(from:))
            ))
        }
        if let title = clip as? TitleSequence {
            return .title(TitleSequenceData(
                clipID: title.clipID?.rawValue,
                text: title.text,
                fontSize: title.style.fontSize,
                fontWeight: documentFontWeight(from: title.style.weight),
                colorHex: hexString(from: title.style.color),
                alignment: documentAlignment(from: title.style.alignment),
                durationSeconds: CMTimeGetSeconds(title.duration),
                transform: title.transform.map(documentTransform(from:))
            ))
        }
        if let transition = clip as? Kadr.Transition {
            return .transition(TransitionData(
                kind: documentTransitionKind(from: transition),
                durationSeconds: CMTimeGetSeconds(transition.duration)
            ))
        }
        if let track = clip as? Track {
            return .track(TrackData(
                startTimeSeconds: track.startTime.map(CMTimeGetSeconds) ?? 0,
                name: track.name,
                opacityFactor: track.opacityFactor,
                clips: track.clips.compactMap(documentClip(from:))
            ))
        }
        return nil
    }

    nonisolated static func documentVideoClip(from clip: VideoClip) -> VideoClipData {
        VideoClipData(
            clipID: clip.clipID?.rawValue,
            url: clip.url,
            trimStartSeconds: clip.trimRange.map { CMTimeGetSeconds($0.start) },
            trimDurationSeconds: clip.trimRange.map { CMTimeGetSeconds($0.duration) },
            isReversed: clip.isReversed,
            isMuted: clip.isMuted,
            speedRate: clip.speedRate,
            opacity: clip.opacity,
            filters: clip.filters.compactMap(documentFilter(from:)),
            transform: clip.transform.map(documentTransform(from:)),
            transformAnimation: clip.transformAnimation.map(documentTransformAnimation(from:)),
            opacityAnimation: clip.opacityAnimation.map(documentDoubleAnimation(from:)),
            filterAnimations: documentFilterAnimations(from: clip.filterAnimations),
            speedCurve: clip.speedCurve.map(documentDoubleAnimation(from:))
        )
    }

    /// Map kadr's parallel filter-animation array to its persisted form,
    /// preserving index alignment with `filters`.
    nonisolated static func documentFilterAnimations(
        from animations: [Kadr.Animation<Double>?]
    ) -> [ProjectAnimation<Double>?]? {
        guard !animations.isEmpty,
              animations.contains(where: { $0 != nil }) else { return nil }
        return animations.map { $0.map(documentDoubleAnimation(from:)) }
    }

    nonisolated static func documentFilter(from filter: Filter) -> ProjectFilter? {
        switch filter {
        case .brightness(let v):    return .brightness(v)
        case .contrast(let v):      return .contrast(v)
        case .saturation(let v):    return .saturation(v)
        case .exposure(let v):      return .exposure(v)
        case .sepia(let v):         return .sepia(v)
        case .gaussianBlur(let v):  return .gaussianBlur(v)
        case .vignette(let v):      return .vignette(v)
        case .sharpen(let v):       return .sharpen(v)
        case .zoomBlur(let v):      return .zoomBlur(v)
        case .glow(let v):          return .glow(v)
        case .mono:                 return .mono
        case .lut(let lut):         return .lut(url: lut.url)
        case .chromaKey(let key):
            return .chromaKey(
                r: key.color.r,
                g: key.color.g,
                b: key.color.b,
                threshold: key.threshold
            )
        }
    }

    nonisolated static func documentTransform(from t: Transform) -> ProjectTransform {
        let xy = positionXY(t.center)
        return ProjectTransform(
            centerX: xy.x,
            centerY: xy.y,
            rotation: t.rotation,
            scale: t.scale,
            anchor: documentAnchor(from: t.anchor)
        )
    }

    nonisolated static func documentOverlay(from overlay: any Overlay) -> ProjectOverlay? {
        if let text = overlay as? TextOverlay {
            return .text(TextOverlayData(
                layerID: text.layerID?.rawValue,
                text: text.text,
                fontSize: text.style.fontSize,
                fontWeight: documentFontWeight(from: text.style.weight),
                colorHex: hexString(from: text.style.color),
                alignment: documentAlignment(from: text.style.alignment),
                positionX: positionXY(text.position).x,
                positionY: positionXY(text.position).y,
                anchor: documentAnchor(from: text.anchor),
                opacity: text.opacity
            ))
        }
        if let image = overlay as? ImageOverlay {
            guard let storage = imageStorage(from: image.image) else { return nil }
            return .image(ImageOverlayData(
                layerID: image.layerID?.rawValue,
                storage: storage,
                positionX: positionXY(image.position).x,
                positionY: positionXY(image.position).y,
                anchor: documentAnchor(from: image.anchor),
                opacity: image.opacity
            ))
        }
        if let sticker = overlay as? StickerOverlay {
            guard let storage = imageStorage(from: sticker.image) else { return nil }
            return .sticker(StickerOverlayData(
                layerID: sticker.layerID?.rawValue,
                storage: storage,
                positionX: positionXY(sticker.position).x,
                positionY: positionXY(sticker.position).y,
                anchor: documentAnchor(from: sticker.anchor),
                opacity: sticker.opacity,
                rotationRadians: sticker.rotation
            ))
        }
        return nil
    }

    nonisolated static func documentAudioTrack(from track: AudioTrack) -> ProjectAudioTrack {
        ProjectAudioTrack(
            url: track.url,
            startTimeSeconds: track.startTime.map { CMTimeGetSeconds($0) },
            explicitDurationSeconds: track.explicitDuration.map { CMTimeGetSeconds($0) },
            volume: track.volumeLevel,
            fadeInSeconds: CMTimeCompare(track.fadeInDuration, .zero) > 0
                ? CMTimeGetSeconds(track.fadeInDuration) : nil,
            fadeOutSeconds: CMTimeCompare(track.fadeOutDuration, .zero) > 0
                ? CMTimeGetSeconds(track.fadeOutDuration) : nil,
            duckingTargetVolume: track.duckingLevel,
            crossfadeDurationSeconds: track.crossfadeDuration.map { CMTimeGetSeconds($0) }
        )
    }

    nonisolated static func documentCaption(from caption: Caption) -> ProjectCaption {
        ProjectCaption(
            text: caption.text,
            startSeconds: CMTimeGetSeconds(caption.timeRange.start),
            durationSeconds: CMTimeGetSeconds(caption.timeRange.duration)
        )
    }

    nonisolated static func documentPreset(from preset: Preset) -> ProjectPreset {
        switch preset {
        case .auto:           return .auto
        case .reelsAndShorts: return .reelsAndShorts
        case .tiktok:         return .tiktok
        case .square:         return .square
        case .cinema:         return .cinema
        case .custom(let w, let h, let fps, let codec):
            return .custom(width: w, height: h, frameRate: fps, codecHEVC: codec == .hevc)
        }
    }

    // MARK: - Enum mappings

    nonisolated static func textAlignment(from a: ProjectTextAlignment) -> TextStyle.Alignment {
        switch a {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }

    nonisolated static func documentAlignment(from a: TextStyle.Alignment) -> ProjectTextAlignment {
        switch a {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }

    nonisolated static func fontWeight(from w: ProjectFontWeight) -> TextStyle.Weight {
        switch w {
        case .regular: return .regular
        case .medium:  return .medium
        case .bold:    return .bold
        }
    }

    nonisolated static func documentFontWeight(from w: TextStyle.Weight) -> ProjectFontWeight {
        switch w {
        case .regular: return .regular
        case .medium:  return .medium
        case .bold:    return .bold
        }
    }

    nonisolated static func anchor(from a: ProjectAnchor) -> Kadr.Anchor {
        switch a {
        case .topLeft:     return .topLeft
        case .top:         return .top
        case .topRight:    return .topRight
        case .left:        return .left
        case .center:      return .center
        case .right:       return .right
        case .bottomLeft:  return .bottomLeft
        case .bottom:      return .bottom
        case .bottomRight: return .bottomRight
        }
    }

    nonisolated static func documentAnchor(from a: Kadr.Anchor) -> ProjectAnchor {
        switch a {
        case .topLeft:     return .topLeft
        case .top:         return .top
        case .topRight:    return .topRight
        case .left:        return .left
        case .center:      return .center
        case .right:       return .right
        case .bottomLeft:  return .bottomLeft
        case .bottom:      return .bottom
        case .bottomRight: return .bottomRight
        }
    }

    nonisolated static func documentTransitionKind(from t: Kadr.Transition) -> TransitionData.TransitionKind {
        switch t {
        case .dissolve: return .dissolve
        case .fade, .slide: return .fade   // slide collapses to fade in v0.2
        }
    }

    nonisolated static func positionXY(_ position: Position) -> (x: Double, y: Double) {
        switch position {
        case .normalized(let x, let y):
            return (x, y)
        case .percent(let x, let y):
            return (x / 100.0, y / 100.0)
        case .pixels:
            return (0.5, 0.5)
        }
    }

    // MARK: - Image storage round-trip

    /// PNG-encode a `PlatformImage` into ``ImageStorage/embeddedPNG(_:)``.
    /// Returns `nil` if the image can't be PNG-encoded (rare; defensive).
    nonisolated static func imageStorage(from image: PlatformImage) -> ImageStorage? {
        guard let data = pngData(from: image) else { return nil }
        return .embeddedPNG(data)
    }

    nonisolated static func platformImage(from storage: ImageStorage) -> PlatformImage? {
        switch storage {
        case .url(let url):
            #if canImport(UIKit)
            return UIImage(contentsOfFile: url.path)
            #elseif canImport(AppKit)
            return NSImage(contentsOf: url)
            #else
            return nil
            #endif
        case .embeddedPNG(let data):
            #if canImport(UIKit)
            return UIImage(data: data)
            #elseif canImport(AppKit)
            return NSImage(data: data)
            #else
            return nil
            #endif
        }
    }

    nonisolated static func pngData(from image: PlatformImage) -> Data? {
        #if canImport(UIKit)
        return image.pngData()
        #elseif canImport(AppKit)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    /// Encode a `PlatformColor` as `#RRGGBBAA` hex. Returns `nil` for colors
    /// whose components can't be extracted (very rare — pattern-based colors,
    /// or NSColor in a non-RGB color space). Cross-platform via UIKit /
    /// AppKit branches.
    nonisolated static func hexString(from color: PlatformColor) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #else
        guard let converted = color.usingColorSpace(.sRGB) else { return nil }
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        let R = Int((max(0, min(1, r)) * 255).rounded())
        let G = Int((max(0, min(1, g)) * 255).rounded())
        let B = Int((max(0, min(1, b)) * 255).rounded())
        let A = Int((max(0, min(1, a)) * 255).rounded())
        if A == 255 {
            return String(format: "#%02X%02X%02X", R, G, B)
        }
        return String(format: "#%02X%02X%02X%02X", R, G, B, A)
    }

    nonisolated static func platformColor(forHex hex: String?) -> PlatformColor? {
        guard let hex else { return nil }
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >>  8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >>  8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }
        #if canImport(UIKit)
        return PlatformColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        #else
        return PlatformColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        #endif
    }
}
