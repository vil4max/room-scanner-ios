import Foundation

struct FinishScanResult: Sendable, Equatable {
    let session: ScanSession
    let requiresQualityConfirmation: Bool
}

struct FinishScan: Sendable {
    private let store: any ScanSessionStoring

    init(store: any ScanSessionStoring) {
        self.store = store
    }

    func callAsFunction(snapshot: ScanMetricsSnapshot, forcePoorQuality: Bool) async throws -> FinishScanResult {
        let quality = ScanQualityEvaluator.evaluate(snapshot: snapshot)
        let session = ScanSession(
            id: UUID(),
            createdAt: Date(),
            duration: snapshot.duration,
            anchorCount: snapshot.anchorCount,
            meshElementCount: snapshot.meshElementCount,
            combinedPointCount: snapshot.combinedPointCount,
            quality: quality
        )
        if quality == .poor, !forcePoorQuality {
            return FinishScanResult(session: session, requiresQualityConfirmation: true)
        }
        try await store.save(session)
        return FinishScanResult(session: session, requiresQualityConfirmation: false)
    }
}

struct LoadScanHistory: Sendable {
    private let store: any ScanSessionStoring

    init(store: any ScanSessionStoring) {
        self.store = store
    }

    func callAsFunction() async throws -> [ScanSession] {
        try await store.loadAll()
    }
}
