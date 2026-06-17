import Foundation
import Testing
@testable import RoomScanner

struct ScanGuidanceEvaluatorTests {
  @Test func moveDeviceWhenNoProgress() {
    let previous = ScanMetricsSnapshot(
      duration: 10,
      featurePointCount: 100,
      anchorCount: 2,
      meshElementCount: 120,
      combinedPointCount: 220,
      coverageEstimate: 0.2,
      trackingState: .normal,
      capturedAt: Date()
    )
    let current = ScanMetricsSnapshot(
      duration: 15,
      featurePointCount: 110,
      anchorCount: 2,
      meshElementCount: 120,
      combinedPointCount: 230,
      coverageEstimate: 0.2,
      trackingState: .normal,
      capturedAt: Date()
    )
    let guidance = ScanGuidanceEvaluator.guidance(
      current: current,
      previous: previous,
      elapsedSinceProgress: 5
    )
    #expect(guidance == .moveDevice)
  }

  @Test func trackingLimitedTakesPriority() {
    let snapshot = ScanMetricsSnapshot(
      duration: 5,
      featurePointCount: 0,
      anchorCount: 0,
      meshElementCount: 0,
      combinedPointCount: 0,
      coverageEstimate: 0,
      trackingState: .limitedInsufficientFeatures,
      capturedAt: Date()
    )
    let guidance = ScanGuidanceEvaluator.guidance(
      current: snapshot,
      previous: nil,
      elapsedSinceProgress: 0
    )
    #expect(guidance == .trackingLimited)
  }
}
