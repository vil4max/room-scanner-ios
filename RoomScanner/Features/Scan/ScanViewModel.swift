import ARKit
import Foundation

@Observable
@MainActor
final class ScanViewModel {
    private let finishScan: FinishScan
    private let arSessionService: any ARSessionProviding
    private var latestSnapshot: ScanMetricsSnapshot?
    private var lastProgressSnapshot: ScanMetricsSnapshot?
    private var lastProgressDate: Date?
    private var noticeClearTask: Task<Void, Never>?

    var durationText = "0:00"
    var featurePointText = "0"
    var anchorText = "0"
    var meshElementText = "0"
    var combinedPointText = "0"
    var coverageText = "0%"
    var trackingText = "Not Available"
    var quality: ScanQuality = .poor
    var guidanceMessage: String?
    var guidanceStyle: ScanStatusBanner.Style = .neutral
    var placementNotice: String?
    var hasPlacedFigure = false
    var placementResetToken = 0

    var arSession: ARSession {
        arSessionService.session
    }

    init(finishScan: FinishScan, arSessionService: any ARSessionProviding) {
        self.finishScan = finishScan
        self.arSessionService = arSessionService
        arSessionService.setMetricsHandler { [weak self] snapshot in
            self?.handleMetricsUpdate(snapshot)
        }
    }

    func onAppear() {
        arSessionService.activateSession()
        arSessionService.beginScan()
        lastProgressSnapshot = nil
        lastProgressDate = Date()
        CaptureLog.capture.debug("ScanView appeared")
    }

    func onDisappear() {
        arSessionService.endScan()
        arSessionService.pauseSession()
        noticeClearTask?.cancel()
        CaptureLog.capture.debug("ScanView disappeared")
    }

    func resetSession() {
        placementResetToken += 1
        hasPlacedFigure = false
        arSessionService.pauseSession()
        arSessionService.activateSession()
        arSessionService.beginScan()
        lastProgressSnapshot = nil
        lastProgressDate = Date()
        CaptureLog.session.notice("ARSession reset requested")
    }

    func handleFigurePlaced() {
        hasPlacedFigure = true
        placementNotice = nil
        Task {
            await saveDevSnapshot()
        }
    }

    func handlePlacementIssue(_ issue: FigurePlacementIssue) {
        switch issue {
        case .modelLoading:
            showPlacementNotice("Loading figure…")
        case .floorNotFound:
            showPlacementNotice("Couldn't find a floor here")
        }
    }

    private func showPlacementNotice(_ message: String) {
        placementNotice = message
        noticeClearTask?.cancel()
        noticeClearTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            placementNotice = nil
        }
    }

    private func handleMetricsUpdate(_ snapshot: ScanMetricsSnapshot) {
        latestSnapshot = snapshot
        let meshProgress = snapshot.meshElementCount - (lastProgressSnapshot?.meshElementCount ?? 0)
        let coverageProgress = snapshot.coverageEstimate - (lastProgressSnapshot?.coverageEstimate ?? 0)
        if meshProgress > 0 || coverageProgress >= 0.01 {
            lastProgressSnapshot = snapshot
            lastProgressDate = Date()
        }
        apply(snapshot: snapshot)
    }

    private func saveDevSnapshot() async {
        guard let snapshot = latestSnapshot else {
            CaptureLog.capture.error("Dev snapshot skipped: missing metrics snapshot")
            return
        }
        do {
            let result = try await finishScan(snapshot: snapshot, forcePoorQuality: true)
            CaptureLog.capture.info(
                "Dev snapshot saved id=\(result.session.id.uuidString) quality=\(result.session.quality.rawValue)"
            )
        } catch {
            CaptureLog.capture.error("Dev snapshot save failed error=\(error.localizedDescription)")
        }
    }

    private func apply(snapshot: ScanMetricsSnapshot) {
        durationText = ScanMetricsFormatter.duration(snapshot.duration)
        featurePointText = ScanMetricsFormatter.integer(snapshot.featurePointCount)
        anchorText = ScanMetricsFormatter.integer(snapshot.anchorCount)
        meshElementText = ScanMetricsFormatter.integer(snapshot.meshElementCount)
        combinedPointText = ScanMetricsFormatter.integer(snapshot.combinedPointCount)
        coverageText = ScanMetricsFormatter.percent(snapshot.coverageEstimate)
        trackingText = ScanMetricsFormatter.trackingLabel(snapshot.trackingState)
        quality = ScanQualityEvaluator.evaluate(snapshot: snapshot)
        let elapsed = Date().timeIntervalSince(lastProgressDate ?? snapshot.capturedAt)
        if let guidance = ScanGuidanceEvaluator.guidance(
            current: snapshot,
            previous: lastProgressSnapshot,
            elapsedSinceProgress: elapsed
        ) {
            switch guidance {
            case .moveDevice:
                guidanceMessage = "Move device to capture more geometry"
                guidanceStyle = .warning
            case .trackingLimited:
                guidanceMessage = trackingText
                guidanceStyle = .danger
            }
        } else {
            guidanceMessage = nil
            guidanceStyle = .neutral
        }
    }
}
