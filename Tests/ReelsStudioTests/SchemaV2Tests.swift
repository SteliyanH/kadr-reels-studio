import XCTest
import CoreMedia
import Kadr
@testable import ReelsStudio
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Tests for v0.3 Tier 1 — schema v2 additions: ProjectAnimation generic,
/// per-value-type bridges, Track round-trip, speed curve, schema migration
/// from v1.
final class SchemaV2Tests: XCTestCase {

    private func roundTrip(_ doc: ProjectDocument) throws -> ProjectDocument {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(doc)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProjectDocument.self, from: data)
    }

    private func cmt(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }

    /// Generate a real 1×1 PNG so the runtime bridge can actually decode it.
    /// Empty data fails `UIImage(data:)` / `NSImage(data:)`.
    private func tinyPNG() -> Data {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData() ?? Data()
        #else
        let image = NSImage(size: CGSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return Data() }
        return rep.representation(using: .png, properties: [:]) ?? Data()
        #endif
    }

    // MARK: - Schema version

    func testNewDocumentReportsCurrentSchema() {
        let doc = ProjectDocument(name: "x")
        XCTAssertEqual(doc.schemaVersion, ProjectDocument.currentSchemaVersion)
    }

    // MARK: - V1 documents migrate forward (additive — missing v2 fields default)

    func testV1JSONLoadsCleanly() throws {
        // Build a v1 document by encoding a v2-shaped one with all the
        // new fields blank, then patching the schemaVersion. This
        // produces JSON in the same Codable shape the v0.2 release wrote
        // (default-synthesized sumtype encoding with `_0` keys, ISO-8601
        // dates, etc.). The point of the test is to verify that the new
        // v2-only fields decode to nil / [] when missing.
        let v1Doc = ProjectDocument(
            name: "Legacy",
            schemaVersion: 1,
            clips: [
                .video(VideoClipData(
                    url: URL(fileURLWithPath: "/tmp/x.mp4"),
                    speedRate: 1.0
                ))
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(v1Doc)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(ProjectDocument.self, from: data)
        XCTAssertEqual(restored.schemaVersion, 1)
        XCTAssertEqual(restored.clips.count, 1)
        guard case .video(let v) = restored.clips.first else {
            return XCTFail("Expected .video")
        }
        XCTAssertNil(v.transformAnimation)
        XCTAssertNil(v.opacityAnimation)
        // filterAnimations is now Optional<[...]> — missing key decodes to nil.
        XCTAssertNil(v.speedCurve)
    }

    // MARK: - ProjectAnimation round-trip

    func testProjectAnimationDoubleRoundTrips() throws {
        let animation = ProjectAnimation<Double>(
            keyframes: [
                ProjectKeyframe(timeSeconds: 0, value: 0.0),
                ProjectKeyframe(timeSeconds: 1.5, value: 0.5),
                ProjectKeyframe(timeSeconds: 3.0, value: 1.0),
            ],
            timing: .easeInOut
        )
        let clip = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            opacity: 1.0,
            opacityAnimation: animation
        )
        let doc = ProjectDocument(name: "Animated", clips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = restored.clips.first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.opacityAnimation?.keyframes.count, 3)
        XCTAssertEqual(v.opacityAnimation?.keyframes[1].timeSeconds, 1.5)
        XCTAssertEqual(v.opacityAnimation?.timing, .easeInOut)
    }

    func testCubicBezierTimingRoundTrips() throws {
        let animation = ProjectAnimation<Double>(
            keyframes: [ProjectKeyframe(timeSeconds: 0, value: 0)],
            timing: .cubicBezier(p1x: 0.42, p1y: 0, p2x: 0.58, p2y: 1)
        )
        let clip = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            opacity: 1.0,
            opacityAnimation: animation
        )
        let doc = ProjectDocument(name: "Bezier", clips: [.video(clip)])
        let restored = try roundTrip(doc)
        guard case .video(let v) = restored.clips.first,
              case .cubicBezier(let p1x, let p1y, let p2x, let p2y) = v.opacityAnimation?.timing else {
            return XCTFail("Expected cubicBezier timing")
        }
        XCTAssertEqual(p1x, 0.42, accuracy: 0.0001)
        XCTAssertEqual(p1y, 0, accuracy: 0.0001)
        XCTAssertEqual(p2x, 0.58, accuracy: 0.0001)
        XCTAssertEqual(p2y, 1, accuracy: 0.0001)
    }

    // MARK: - Track round-trip

    func testTrackRoundTrips() throws {
        let inner = ImageClipData(
            storage: .embeddedPNG(Data([0x89, 0x50])),
            durationSeconds: 1.5
        )
        let track = TrackData(
            startTimeSeconds: 2.0,
            name: "B-roll",
            opacityFactor: 0.7,
            clips: [.image(inner)]
        )
        let doc = ProjectDocument(name: "Track", clips: [.track(track)])
        let restored = try roundTrip(doc)
        guard case .track(let t) = restored.clips.first else {
            return XCTFail("Expected .track")
        }
        XCTAssertEqual(t.startTimeSeconds, 2.0)
        XCTAssertEqual(t.name, "B-roll")
        XCTAssertEqual(t.opacityFactor, 0.7)
        XCTAssertEqual(t.clips.count, 1)
    }

    // MARK: - Speed curve survives bridge

    func testSpeedCurveRoundTripsThroughBridge() {
        let curveData = ProjectAnimation<Double>(
            keyframes: [
                ProjectKeyframe(timeSeconds: 0, value: 1.0),
                ProjectKeyframe(timeSeconds: 1.0, value: 0.5),
                ProjectKeyframe(timeSeconds: 2.0, value: 1.0),
            ],
            timing: .linear
        )
        let clipData = VideoClipData(
            url: URL(fileURLWithPath: "/tmp/x.mp4"),
            trimStartSeconds: 0,
            trimDurationSeconds: 2.0,
            speedCurve: curveData
        )
        let doc = ProjectDocument(name: "SpeedCurve", clips: [.video(clipData)])
        // Document → runtime → document, verifying the curve survives both
        // legs of the bridge.
        let runtime = doc.toRuntimeProject()
        let rebuilt = runtime.toDocument(inheriting: doc, name: doc.name)
        guard case .video(let v) = rebuilt.clips.first else {
            return XCTFail("Expected .video")
        }
        XCTAssertEqual(v.speedCurve?.keyframes.count, 3)
        XCTAssertEqual(v.speedCurve?.keyframes[1].timeSeconds ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(v.speedCurve?.keyframes[1].value ?? 0, 0.5, accuracy: 0.0001)
    }

    // MARK: - Track round-trip through bridge

    func testTrackBridgeRoundTrips() {
        let inner = ImageClipData(
            storage: .embeddedPNG(tinyPNG()),
            durationSeconds: 1.0
        )
        let track = TrackData(
            startTimeSeconds: 1.0,
            name: "Cutaway",
            opacityFactor: 0.5,
            clips: [.image(inner)]
        )
        let doc = ProjectDocument(name: "T", clips: [.track(track)])
        let runtime = doc.toRuntimeProject()
        XCTAssertEqual(runtime.clips.count, 1)
        XCTAssertNotNil(runtime.clips.first as? Track)
        let rebuilt = runtime.toDocument(inheriting: doc, name: doc.name)
        guard case .track(let t) = rebuilt.clips.first else {
            return XCTFail("Expected .track")
        }
        XCTAssertEqual(t.name, "Cutaway")
        XCTAssertEqual(t.opacityFactor, 0.5, accuracy: 0.0001)
    }

    // MARK: - Animations survive runtime bridge

    func testTransformAnimationSurvivesRuntimeBridge() {
        let curveData = ProjectAnimation<ProjectTransform>(
            keyframes: [
                ProjectKeyframe(
                    timeSeconds: 0,
                    value: ProjectTransform(centerX: 0.5, centerY: 0.5, rotation: 0, scale: 1.0, anchor: .center)
                ),
                ProjectKeyframe(
                    timeSeconds: 2.0,
                    value: ProjectTransform(centerX: 0.5, centerY: 0.5, rotation: 0, scale: 1.5, anchor: .center)
                ),
            ],
            timing: .easeInOut
        )
        let clipData = ImageClipData(
            storage: .embeddedPNG(tinyPNG()),
            durationSeconds: 2.0,
            transform: ProjectTransform(),
            transformAnimation: curveData
        )
        let doc = ProjectDocument(name: "Anim", clips: [.image(clipData)])
        let runtime = doc.toRuntimeProject()
        let rebuilt = runtime.toDocument(inheriting: doc, name: doc.name)
        guard case .image(let i) = rebuilt.clips.first else {
            return XCTFail("Expected .image")
        }
        XCTAssertEqual(i.transformAnimation?.keyframes.count, 2)
        XCTAssertEqual(i.transformAnimation?.keyframes[1].value.scale ?? 0, 1.5, accuracy: 0.0001)
    }
}
