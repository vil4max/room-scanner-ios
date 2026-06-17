import Foundation

enum ScanQuality: String, Codable, Sendable, CaseIterable {
    case poor
    case fair
    case good
}

struct ScanSession: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let createdAt: Date
    let duration: TimeInterval
    let anchorCount: Int
    let meshElementCount: Int
    let combinedPointCount: Int
    let quality: ScanQuality

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case duration
        case anchorCount
        case meshElementCount
        case combinedPointCount
        case pointCloudPointCount
        case quality
    }

    init(
        id: UUID,
        createdAt: Date,
        duration: TimeInterval,
        anchorCount: Int,
        meshElementCount: Int,
        combinedPointCount: Int,
        quality: ScanQuality
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.anchorCount = anchorCount
        self.meshElementCount = meshElementCount
        self.combinedPointCount = combinedPointCount
        self.quality = quality
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        anchorCount = try container.decode(Int.self, forKey: .anchorCount)
        meshElementCount = try container.decode(Int.self, forKey: .meshElementCount)
        if let combined = try container.decodeIfPresent(Int.self, forKey: .combinedPointCount) {
            combinedPointCount = combined
        } else {
            combinedPointCount = try container.decode(Int.self, forKey: .pointCloudPointCount)
        }
        quality = try container.decode(ScanQuality.self, forKey: .quality)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(duration, forKey: .duration)
        try container.encode(anchorCount, forKey: .anchorCount)
        try container.encode(meshElementCount, forKey: .meshElementCount)
        try container.encode(combinedPointCount, forKey: .combinedPointCount)
        try container.encode(quality, forKey: .quality)
    }
}

enum TrackingStateKind: String, Sendable, Equatable {
    case notAvailable
    case normal
    case limitedExcessiveMotion
    case limitedInsufficientFeatures
    case limitedInitializing
    case limitedRelocalizing
    case limitedOther
}

struct ScanMetricsSnapshot: Sendable, Equatable {
    let duration: TimeInterval
    let featurePointCount: Int
    let anchorCount: Int
    let meshElementCount: Int
    let combinedPointCount: Int
    let coverageEstimate: Double
    let trackingState: TrackingStateKind
    let capturedAt: Date
}
