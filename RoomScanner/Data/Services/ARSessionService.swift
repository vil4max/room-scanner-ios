import ARKit
import Foundation

@MainActor
protocol ARSessionProviding: AnyObject {
    var session: ARSession { get }
    var meshReconstructionEnabled: Bool { get }
    func activateSession()
    func beginScan()
    func endScan()
    func pauseSession()
    func setMetricsHandler(_ handler: @escaping (ScanMetricsSnapshot) -> Void)
}

@MainActor
final class ARSessionService: NSObject, ARSessionProviding {
    let session = ARSession()

    private var isSessionActive = false
    private var isScanning = false
    private var scanStartedAt: Date?
    private var metricsHandler: ((ScanMetricsSnapshot) -> Void)?
    private var lastMetricsLogDate = Date.distantPast
    private var lastLoggedTrackingState: TrackingStateKind?

    var meshReconstructionEnabled: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    override init() {
        super.init()
        session.delegate = self
        CaptureLog.session.info("ARSessionService initialized meshSupported=\(self.meshReconstructionEnabled)")
    }

    func setMetricsHandler(_ handler: @escaping (ScanMetricsSnapshot) -> Void) {
        metricsHandler = handler
    }

    func activateSession() {
        guard !isSessionActive else { return }
        if session.currentFrame != nil {
            isSessionActive = true
            CaptureLog.session.info("ARSession already active")
            return
        }
        runConfiguration(reset: true)
        isSessionActive = true
        CaptureLog.session.info("ARSession activated")
    }

    func beginScan() {
        if !isSessionActive {
            activateSession()
        }
        isScanning = true
        scanStartedAt = Date()
        CaptureLog.capture.info("Scan started")
    }

    func endScan() {
        isScanning = false
        scanStartedAt = nil
        CaptureLog.capture.info("Scan ended")
    }

    func pauseSession() {
        session.pause()
        isSessionActive = false
        isScanning = false
        scanStartedAt = nil
        CaptureLog.session.info("ARSession paused")
    }

    private func runConfiguration(reset: Bool) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if meshReconstructionEnabled {
            configuration.sceneReconstruction = .meshWithClassification
        }
        configuration.environmentTexturing = .automatic
        let options: ARSession.RunOptions = reset ? [.resetTracking, .removeExistingAnchors] : []
        session.run(configuration, options: options)
        CaptureLog.session.debug(
            "ARConfiguration planes=horizontal,vertical mesh=\(self.meshReconstructionEnabled) reset=\(reset)"
        )
    }

    private func deliverMetrics(from payload: ScanMetricsFramePayload) {
        let snapshot = ScanMetricsService.makeSnapshot(
            payload: payload,
            scanStartedAt: scanStartedAt,
            isScanning: isScanning
        )
        metricsHandler?(snapshot)
        logMetricsIfNeeded(snapshot)
    }

    private func logMetricsIfNeeded(_ snapshot: ScanMetricsSnapshot) {
        guard isScanning else { return }
        let now = Date()
        guard now.timeIntervalSince(lastMetricsLogDate) >= 2 else { return }
        lastMetricsLogDate = now
        CaptureLog.metrics.info(
            "duration=\(snapshot.duration, format: .fixed(precision: 1)) anchors=\(snapshot.anchorCount) mesh=\(snapshot.meshElementCount) features=\(snapshot.featurePointCount) coverage=\(snapshot.coverageEstimate, format: .fixed(precision: 2)) tracking=\(snapshot.trackingState.rawValue)"
        )
    }

    private func logTrackingChangeIfNeeded(_ state: TrackingStateKind) {
        guard lastLoggedTrackingState != state else { return }
        lastLoggedTrackingState = state
        CaptureLog.session.notice("trackingState=\(state.rawValue)")
    }
}

extension ARSessionService: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let payload = ScanMetricsFramePayload(frame: frame)
        Task { @MainActor [weak self] in
            self?.deliverMetrics(from: payload)
        }
    }

    nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let kind = ScanMetricsService.trackingKind(for: camera.trackingState)
        Task { @MainActor [weak self] in
            self?.logTrackingChangeIfNeeded(kind)
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            CaptureLog.session.error("ARSession interrupted")
        }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            CaptureLog.session.notice("ARSession interruption ended")
            guard isSessionActive else { return }
            runConfiguration(reset: false)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            CaptureLog.session.error("ARSession failed error=\(error.localizedDescription)")
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        let meshCount = anchors.filter { $0 is ARMeshAnchor }.count
        let planeCount = anchors.filter { $0 is ARPlaneAnchor }.count
        guard meshCount > 0 || planeCount > 0 else { return }
        Task { @MainActor in
            CaptureLog.session.debug("anchorsAdded mesh=\(meshCount) planes=\(planeCount)")
        }
    }
}
