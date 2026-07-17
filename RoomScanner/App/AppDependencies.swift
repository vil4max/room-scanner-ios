import Foundation

@MainActor
final class AppDependencies {
    let scanViewModel: ScanViewModel
    let historyViewModel: ScanHistoryViewModel
    let captureViewModel: CaptureViewModel
    let aiResultViewModel: AIResultViewModel
    let arSessionService: ARSessionService

    init(
        store: any ScanSessionStoring = ScanSessionStore(),
        captureExporter: any CapturePackageExporting = CapturePackageExporter(),
        modelImporter: any ModelImporting = ModelImportService()
    ) {
        let finishScan = FinishScan(store: store)
        let loadScanHistory = LoadScanHistory(store: store)
        let arSessionService = ARSessionService()
        self.arSessionService = arSessionService
        scanViewModel = ScanViewModel(
            finishScan: finishScan,
            arSessionService: arSessionService
        )
        historyViewModel = ScanHistoryViewModel(loadScanHistory: loadScanHistory)
        // Separate AR session for AI capture so Scan lab state stays isolated.
        captureViewModel = CaptureViewModel(
            recorder: AICaptureRecorder(),
            exporter: captureExporter
        )
        aiResultViewModel = AIResultViewModel(importer: modelImporter)
    }
}
