import Foundation
import Testing
@testable import RoomScanner

struct ScanQualityEvaluatorTests {
  @Test func poorWhenTrackingLimited() {
    let snapshot = ScanMetricsSnapshot(
      duration: 30,
      featurePointCount: 500,
      anchorCount: 10,
      meshElementCount: 500,
      combinedPointCount: 1000,
      coverageEstimate: 0.5,
      trackingState: .limitedExcessiveMotion,
      capturedAt: Date()
    )
    #expect(ScanQualityEvaluator.evaluate(snapshot: snapshot) == .poor)
  }

  @Test func goodWhenMetricsHigh() {
    let snapshot = ScanMetricsSnapshot(
      duration: 60,
      featurePointCount: 800,
      anchorCount: 12,
      meshElementCount: 600,
      combinedPointCount: 1400,
      coverageEstimate: 0.5,
      trackingState: .normal,
      capturedAt: Date()
    )
    #expect(ScanQualityEvaluator.evaluate(snapshot: snapshot) == .good)
  }
}
