import Foundation
import Observation

@MainActor
@Observable
final class CaptureViewModel {
    private let recorder: any AICaptureRecording
    private let exporter: any CapturePackageExporting
    private let packagesDirectory: URL

    var isRecording = false
    var statusMessage = "Walk slowly around the room (30–90s)."
    var lastPackageURL: URL?
    var frameCount = 0
    var depthCount = 0
    var errorMessage: String?
    var shareURL: URL?

    init(
        recorder: any AICaptureRecording,
        exporter: any CapturePackageExporting = CapturePackageExporter(),
        packagesDirectory: URL? = nil
    ) {
        self.recorder = recorder
        self.exporter = exporter
        if let packagesDirectory {
            self.packagesDirectory = packagesDirectory
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.packagesDirectory = docs.appendingPathComponent("AISessions", isDirectory: true)
        }
    }

    func onAppear() {
        recorder.prepare()
        statusMessage = "Ready. Record a walkthrough; LiDAR depth is saved when available."
    }

    func onDisappear() {
        recorder.pause()
        isRecording = false
    }

    func toggleRecording() async {
        errorMessage = nil
        if isRecording {
            await finishRecording()
        } else {
            recorder.start()
            isRecording = true
            statusMessage = "Recording… keep moving slowly for coverage."
        }
    }

    private func finishRecording() async {
        isRecording = false
        let result = await recorder.stop()
        frameCount = result.frameURLs.count
        depthCount = result.depthURLs.count
        statusMessage = "Exporting package…"
        do {
            try FileManager.default.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)
            let url = try await exporter.export(
                sessionId: UUID(),
                videoURL: result.videoURL,
                frameURLs: result.frameURLs,
                depthURLs: result.depthURLs,
                durationSeconds: result.durationSeconds,
                intrinsics: result.intrinsics,
                to: packagesDirectory
            )
            lastPackageURL = url
            shareURL = url
            statusMessage = "Saved \(url.lastPathComponent). AirDrop to Mac → run pipeline."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Export failed."
            CaptureLog.capture.error("AI package export failed: \(error.localizedDescription)")
        }
    }

    func refreshCounts() {
        frameCount = recorder.capturedFrameCount
        depthCount = recorder.capturedDepthCount
    }
}
