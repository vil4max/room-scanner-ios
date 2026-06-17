import Foundation

enum ScanMetricsFormatter {
    static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func integer(_ value: Int) -> String {
        value.formatted()
    }

    static func percent(_ value: Double) -> String {
        let clamped = min(max(value, 0), 1)
        return clamped.formatted(.percent.precision(.fractionLength(0)))
    }

    static func trackingLabel(_ state: TrackingStateKind) -> String {
        switch state {
        case .notAvailable:
            "Tracking unavailable"
        case .normal:
            "Normal"
        case .limitedExcessiveMotion:
            "Move slower"
        case .limitedInsufficientFeatures:
            "More light or detail"
        case .limitedInitializing:
            "Starting…"
        case .limitedRelocalizing:
            "Trying to relocalize"
        case .limitedOther:
            "Tracking limited"
        }
    }
}
