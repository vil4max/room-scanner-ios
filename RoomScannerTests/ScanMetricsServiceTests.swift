import ARKit
import Testing
@testable import RoomScanner

struct ScanMetricsServiceTests {
    @Test func mapsNormalTracking() {
        #expect(ScanMetricsService.trackingKind(for: .normal) == .normal)
    }

    @Test func mapsLimitedExcessiveMotion() {
        #expect(ScanMetricsService.trackingKind(for: .limited(.excessiveMotion)) == .limitedExcessiveMotion)
    }

    @Test func mapsLimitedInsufficientFeatures() {
        #expect(ScanMetricsService.trackingKind(for: .limited(.insufficientFeatures)) == .limitedInsufficientFeatures)
    }
}
