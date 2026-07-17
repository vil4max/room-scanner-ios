import Foundation

/// Metadata written next to video/depth so the Mac CLI can validate packages without guessing.
struct CapturePackageMetadata: Codable, Equatable {
    /// Bump when folder layout or required keys change; Python `SCHEMA_VERSION` must match.
    var schemaVersion: Int
    var sessionId: String
    var createdAt: Date
    var durationSeconds: Double
    var frameCount: Int
    var depthCount: Int
    /// True when depth maps were written; CLI prefers LiDAR unproject when set.
    var hasLidar: Bool
    var intrinsics: CaptureIntrinsics?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case sessionId = "session_id"
        case createdAt = "created_at"
        case durationSeconds = "duration_seconds"
        case frameCount = "frame_count"
        case depthCount = "depth_count"
        case hasLidar = "has_lidar"
        case intrinsics
    }

    static let currentSchemaVersion = 1
}

struct CaptureIntrinsics: Codable, Equatable {
    var fx: Double
    var fy: Double
    var cx: Double
    var cy: Double
    var width: Int
    var height: Int
}
