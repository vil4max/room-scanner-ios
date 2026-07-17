import Foundation

protocol CapturePackageExporting: Sendable {
    func export(
        sessionId: UUID,
        videoURL: URL?,
        frameURLs: [URL],
        depthURLs: [URL],
        durationSeconds: Double,
        intrinsics: CaptureIntrinsics?,
        to rootDirectory: URL
    ) async throws -> URL
}

enum CapturePackageExporterError: Error, Equatable {
    case encodingFailed
    case missingMedia
}

/// Builds the Session_* folder the Python pipeline expects (see docs/ai-pipeline.md).
final class CapturePackageExporter: CapturePackageExporting, @unchecked Sendable {
    private let fileManager: FileManager
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
    }

    func export(
        sessionId: UUID,
        videoURL: URL?,
        frameURLs: [URL],
        depthURLs: [URL],
        durationSeconds: Double,
        intrinsics: CaptureIntrinsics?,
        to rootDirectory: URL
    ) async throws -> URL {
        // Soft-fail rule: need at least video or one frame so Mac CLI validation can proceed.
        guard videoURL != nil || !frameURLs.isEmpty else {
            throw CapturePackageExporterError.missingMedia
        }

        let sessionURL = rootDirectory.appendingPathComponent("Session_\(sessionId.uuidString)", isDirectory: true)
        let framesDir = sessionURL.appendingPathComponent("frames", isDirectory: true)
        let depthDir = sessionURL.appendingPathComponent("depth", isDirectory: true)
        try fileManager.createDirectory(at: framesDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: depthDir, withIntermediateDirectories: true)

        if let videoURL {
            let dest = sessionURL.appendingPathComponent("video.mp4")
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: videoURL, to: dest)
        }

        for url in frameURLs {
            let dest = framesDir.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
        }

        for url in depthURLs {
            let dest = depthDir.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
        }

        let metadata = CapturePackageMetadata(
            schemaVersion: CapturePackageMetadata.currentSchemaVersion,
            sessionId: sessionId.uuidString,
            createdAt: Date(),
            durationSeconds: durationSeconds,
            frameCount: frameURLs.count,
            depthCount: depthURLs.count,
            hasLidar: !depthURLs.isEmpty,
            intrinsics: intrinsics
        )
        guard let data = try? encoder.encode(metadata) else {
            throw CapturePackageExporterError.encodingFailed
        }
        try data.write(to: sessionURL.appendingPathComponent("metadata.json"), options: .atomic)
        CaptureLog.capture.info(
            "AI package exported id=\(sessionId.uuidString) frames=\(frameURLs.count) depth=\(depthURLs.count)"
        )
        return sessionURL
    }
}
