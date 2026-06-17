import Foundation

enum ScanGuidance: Equatable, Sendable {
    case moveDevice
    case trackingLimited
}

enum ScanQualityEvaluator {
    static func evaluate(snapshot: ScanMetricsSnapshot) -> ScanQuality {
        if snapshot.trackingState != .normal {
            return .poor
        }
        if snapshot.meshElementCount < 120 || snapshot.coverageEstimate < 0.15 {
            return .poor
        }
        if snapshot.meshElementCount < 400 || snapshot.coverageEstimate < 0.35 {
            return .fair
        }
        return .good
    }
}

enum ScanGuidanceEvaluator {
    static func guidance(
        current: ScanMetricsSnapshot,
        previous: ScanMetricsSnapshot?,
        elapsedSinceProgress: TimeInterval
    ) -> ScanGuidance? {
        if current.trackingState != .normal {
            return .trackingLimited
        }
        guard let previous else { return nil }
        let meshProgress = current.meshElementCount - previous.meshElementCount
        let coverageProgress = current.coverageEstimate - previous.coverageEstimate
        if elapsedSinceProgress >= 4, meshProgress <= 0, coverageProgress < 0.01 {
            return .moveDevice
        }
        return nil
    }
}
