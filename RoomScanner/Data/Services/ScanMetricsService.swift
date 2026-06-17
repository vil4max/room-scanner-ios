import ARKit
import Foundation

struct ScanMetricsFramePayload: Sendable {
    let featurePointCount: Int
    let anchorCount: Int
    let meshElementCount: Int
    let meshVertexCount: Int
    let coverageEstimate: Double
    let trackingState: TrackingStateKind
    let capturedAt: Date

    nonisolated init(frame: ARFrame) {
        let anchors = frame.anchors
        featurePointCount = frame.rawFeaturePoints?.points.count ?? 0
        anchorCount = anchors.count
        meshElementCount = anchors.reduce(into: 0) { count, anchor in
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            count += meshAnchor.geometry.faces.count
        }
        meshVertexCount = anchors.reduce(into: 0) { count, anchor in
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            count += meshAnchor.geometry.vertices.count
        }
        coverageEstimate = Self.coverageEstimate(for: anchors)
        trackingState = ScanMetricsService.trackingKind(for: frame.camera.trackingState)
        capturedAt = Date()
    }

    private static func coverageEstimate(for anchors: [ARAnchor]) -> Double {
        var planeArea: Float = 0
        var meshFaces = 0
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor {
                planeArea += plane.planeExtent.width * plane.planeExtent.height
            }
            if let mesh = anchor as? ARMeshAnchor {
                meshFaces += mesh.geometry.faces.count
            }
        }
        let planeScore = normalizedRamp(value: Double(planeArea), scale: 30.0)
        let meshScore = normalizedRamp(value: Double(meshFaces), scale: 120_000.0)
        return min(max(planeScore, meshScore), 1.0)
    }

    private static func normalizedRamp(value: Double, scale: Double) -> Double {
        guard value > 0, scale > 0 else { return 0 }
        return 1 - exp(-value / scale)
    }
}

enum ScanMetricsService {
    static func makeSnapshot(
        payload: ScanMetricsFramePayload,
        scanStartedAt: Date?,
        isScanning: Bool
    ) -> ScanMetricsSnapshot {
        let elapsedDuration: TimeInterval
        if isScanning, let scanStartedAt {
            elapsedDuration = max(0, Date().timeIntervalSince(scanStartedAt))
        } else {
            elapsedDuration = 0
        }

        return ScanMetricsSnapshot(
            duration: elapsedDuration,
            featurePointCount: payload.featurePointCount,
            anchorCount: payload.anchorCount,
            meshElementCount: payload.meshElementCount,
            combinedPointCount: payload.featurePointCount + payload.meshVertexCount,
            coverageEstimate: payload.coverageEstimate,
            trackingState: payload.trackingState,
            capturedAt: payload.capturedAt
        )
    }

    static func trackingKind(for state: ARCamera.TrackingState) -> TrackingStateKind {
        switch state {
        case .notAvailable:
            return .notAvailable
        case .normal:
            return .normal
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return .limitedExcessiveMotion
            case .insufficientFeatures:
                return .limitedInsufficientFeatures
            case .initializing:
                return .limitedInitializing
            case .relocalizing:
                return .limitedRelocalizing
            @unknown default:
                return .limitedOther
            }
        }
    }
}
