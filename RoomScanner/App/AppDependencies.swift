import Foundation

@MainActor
final class AppDependencies {
    let scanViewModel: ScanViewModel
    let historyViewModel: ScanHistoryViewModel
    let arSessionService: ARSessionService

    init(store: any ScanSessionStoring = ScanSessionStore()) {
        let finishScan = FinishScan(store: store)
        let loadScanHistory = LoadScanHistory(store: store)
        let arSessionService = ARSessionService()
        self.arSessionService = arSessionService
        scanViewModel = ScanViewModel(
            finishScan: finishScan,
            arSessionService: arSessionService
        )
        historyViewModel = ScanHistoryViewModel(loadScanHistory: loadScanHistory)
    }
}
