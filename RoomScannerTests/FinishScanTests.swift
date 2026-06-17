import Foundation
import Testing
@testable import RoomScanner

struct FinishScanTests {
  @Test func requiresConfirmationForPoorQuality() async throws {
    let store = InMemoryScanSessionStore()
    let finishScan = FinishScan(store: store)
    let snapshot = ScanMetricsSnapshot(
      duration: 5,
      featurePointCount: 10,
      anchorCount: 0,
      meshElementCount: 0,
      combinedPointCount: 10,
      coverageEstimate: 0.01,
      trackingState: .normal,
      capturedAt: Date()
    )
    let result = try await finishScan(snapshot: snapshot, forcePoorQuality: false)
    #expect(result.requiresQualityConfirmation)
    #expect(await store.savedSessions.isEmpty)
  }

  @Test func savesWhenForcedPoorQuality() async throws {
    let store = InMemoryScanSessionStore()
    let finishScan = FinishScan(store: store)
    let snapshot = ScanMetricsSnapshot(
      duration: 5,
      featurePointCount: 10,
      anchorCount: 0,
      meshElementCount: 0,
      combinedPointCount: 10,
      coverageEstimate: 0.01,
      trackingState: .normal,
      capturedAt: Date()
    )
    let result = try await finishScan(snapshot: snapshot, forcePoorQuality: true)
    #expect(!result.requiresQualityConfirmation)
    #expect(await store.savedSessions.count == 1)
  }
}

actor InMemoryScanSessionStore: ScanSessionStoring {
  private(set) var savedSessions: [ScanSession] = []

  func save(_ session: ScanSession) async throws {
    savedSessions.append(session)
  }

  func loadAll() async throws -> [ScanSession] {
    savedSessions.sorted { $0.createdAt > $1.createdAt }
  }
}
