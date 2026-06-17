import Foundation
import Testing
@testable import RoomScanner

struct ScanSessionStoreTests {
  @Test func saveAndLoadRoundTrip() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = ScanSessionStore(directoryURL: directory)
    let session = ScanSession(
      id: UUID(),
      createdAt: Date(),
      duration: 42,
      anchorCount: 3,
      meshElementCount: 120,
      combinedPointCount: 240,
      quality: .fair
    )
    try await store.save(session)
    let loaded = try await store.loadAll()
    #expect(loaded.count == 1)
    let roundTripped = try #require(loaded.first)
    #expect(roundTripped.id == session.id)
    #expect(roundTripped.duration == session.duration)
    #expect(roundTripped.anchorCount == session.anchorCount)
    #expect(roundTripped.meshElementCount == session.meshElementCount)
    #expect(roundTripped.combinedPointCount == session.combinedPointCount)
    #expect(roundTripped.quality == session.quality)
  }
}
