import Foundation
@testable import RoomScanner
import Testing

struct CapturePackageExporterTests {
    @Test func exportWritesMetadataAndMarksLidarWhenDepthPresent() async throws {
        // Tests that metadata marks has_lidar when depth files are exported.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let frame = root.appendingPathComponent("frame_00001.jpg")
        let depth = root.appendingPathComponent("frame_00001.npy")
        try Data([0xFF, 0xD8, 0xFF]).write(to: frame)
        try Data([0x00, 0x01]).write(to: depth)

        let exporter = CapturePackageExporter()
        let sessionURL = try await exporter.export(
            sessionId: UUID(),
            videoURL: nil,
            frameURLs: [frame],
            depthURLs: [depth],
            durationSeconds: 12.5,
            intrinsics: CaptureIntrinsics(fx: 100, fy: 100, cx: 50, cy: 50, width: 100, height: 100),
            to: root
        )

        let metadataURL = sessionURL.appendingPathComponent("metadata.json")
        let data = try Data(contentsOf: metadataURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(CapturePackageMetadata.self, from: data)
        #expect(metadata.schemaVersion == CapturePackageMetadata.currentSchemaVersion)
        #expect(metadata.hasLidar == true)
        #expect(metadata.frameCount == 1)
        #expect(metadata.depthCount == 1)
        #expect(FileManager.default.fileExists(atPath: sessionURL.appendingPathComponent("frames/frame_00001.jpg").path))
        #expect(FileManager.default.fileExists(atPath: sessionURL.appendingPathComponent("depth/frame_00001.npy").path))
    }

    @Test func exportFailsWithoutVideoOrFrames() async {
        // Tests that exporter rejects empty packages with missingMedia.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exporter = CapturePackageExporter()
        await #expect(throws: CapturePackageExporterError.missingMedia) {
            _ = try await exporter.export(
                sessionId: UUID(),
                videoURL: nil,
                frameURLs: [],
                depthURLs: [],
                durationSeconds: 0,
                intrinsics: nil,
                to: root
            )
        }
    }
}
