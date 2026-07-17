import ARKit
import CoreImage
import Foundation
import UIKit

@MainActor
protocol AICaptureRecording: AnyObject {
    var isRecording: Bool { get }
    var capturedFrameCount: Int { get }
    var capturedDepthCount: Int { get }
    var lastIntrinsics: CaptureIntrinsics? { get }
    func prepare()
    func start()
    func stop() async -> AICaptureRecordingResult
    func pause()
}

struct AICaptureRecordingResult {
    var videoURL: URL?
    var frameURLs: [URL]
    var depthURLs: [URL]
    var durationSeconds: Double
    var intrinsics: CaptureIntrinsics?
}

/// Records RGB stills + ARKit scene depth for the offline Mac pipeline.
/// Why ARSession (not AVCapture alone): sceneDepth is metric and aligned to the camera image.
@MainActor
final class AICaptureRecorder: NSObject, AICaptureRecording {
    private let session = ARSession()
    private let fileManager: FileManager
    private let workingDirectory: URL
    private var isSessionRunning = false
    private var recording = false
    private var startedAt: Date?
    private var frameIndex = 0
    private var frameURLs: [URL] = []
    private var depthURLs: [URL] = []
    private var sampleEveryNFrames = 15
    private var frameCounter = 0
    private(set) var lastIntrinsics: CaptureIntrinsics?
    private(set) var capturedFrameCount = 0
    private(set) var capturedDepthCount = 0

    var isRecording: Bool {
        recording
    }

    var supportsSceneDepth: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    init(fileManager: FileManager = .default, workingDirectory: URL? = nil) {
        self.fileManager = fileManager
        if let workingDirectory {
            self.workingDirectory = workingDirectory
        } else {
            let temp = fileManager.temporaryDirectory.appendingPathComponent("ai-capture", isDirectory: true)
            self.workingDirectory = temp
        }
        super.init()
        session.delegate = self
    }

    func prepare() {
        try? fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        runConfiguration()
        isSessionRunning = true
        CaptureLog.capture.info("AICaptureRecorder prepared sceneDepth=\(supportsSceneDepth)")
    }

    func start() {
        if !isSessionRunning {
            prepare()
        }
        clearWorkingFiles()
        frameIndex = 0
        frameCounter = 0
        frameURLs = []
        depthURLs = []
        capturedFrameCount = 0
        capturedDepthCount = 0
        startedAt = Date()
        recording = true
        CaptureLog.capture.info("AI capture recording started")
    }

    func stop() async -> AICaptureRecordingResult {
        recording = false
        let duration = Date().timeIntervalSince(startedAt ?? Date())
        startedAt = nil
        CaptureLog.capture.info(
            "AI capture stopped frames=\(frameURLs.count) depth=\(depthURLs.count) duration=\(duration)"
        )
        return AICaptureRecordingResult(
            videoURL: nil,
            frameURLs: frameURLs,
            depthURLs: depthURLs,
            durationSeconds: duration,
            intrinsics: lastIntrinsics
        )
    }

    func pause() {
        session.pause()
        isSessionRunning = false
        recording = false
    }

    private func runConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        // Scene depth gives float meters per pixel when LiDAR is present (15 Pro).
        if supportsSceneDepth {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    private func clearWorkingFiles() {
        try? fileManager.removeItem(at: workingDirectory)
        try? fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
    }

    private func saveSample(from frame: ARFrame) {
        let index = frameIndex
        frameIndex += 1
        let stem = String(format: "frame_%05d", index + 1)

        let pixelBuffer = frame.capturedImage
        if let image = Self.uiImage(from: pixelBuffer) {
            let url = workingDirectory.appendingPathComponent("\(stem).jpg")
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: url)
                frameURLs.append(url)
                capturedFrameCount = frameURLs.count
            }
        }

        let intrinsics = frame.camera.intrinsics
        let size = frame.camera.imageResolution
        lastIntrinsics = CaptureIntrinsics(
            fx: Double(intrinsics[0, 0]),
            fy: Double(intrinsics[1, 1]),
            cx: Double(intrinsics[2, 0]),
            cy: Double(intrinsics[2, 1]),
            width: Int(size.width),
            height: Int(size.height)
        )

        // Depth map is lower-res than RGB; we still name it like the RGB stem for CLI pairing.
        if let sceneDepth = frame.sceneDepth {
            let depthMap = sceneDepth.depthMap
            if let npy = Self.npyFloat32(from: depthMap) {
                let url = workingDirectory.appendingPathComponent("\(stem).npy")
                try? npy.write(to: url)
                depthURLs.append(url)
                capturedDepthCount = depthURLs.count
            }
        }
    }

    private static func uiImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Minimal .npy writer for float32 HxW depth (Python np.load compatible).
    private static func npyFloat32(from depthMap: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let src = base.assumingMemoryBound(to: Float32.self)
        var floats = [Float32](repeating: 0, count: width * height)
        let floatsPerRow = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.stride
        for y in 0 ..< height {
            for x in 0 ..< width {
                floats[y * width + x] = src[y * floatsPerRow + x]
            }
        }
        return encodeNpy(floats: floats, height: height, width: width)
    }

    private static func encodeNpy(floats: [Float32], height: Int, width: Int) -> Data {
        var data = Data()
        data.append(0x93)
        data.append(contentsOf: Array("NUMPY".utf8))
        data.append(contentsOf: [0x01, 0x00])
        var header = "{'descr': '<f4', 'fortran_order': False, 'shape': (\(height), \(width), ), }"
        let preamble = 10
        let headerBodyLength = header.utf8.count + 1
        let pad = (16 - ((preamble + headerBodyLength) % 16)) % 16
        header += String(repeating: " ", count: pad) + "\n"
        let headerBytes = Array(header.utf8)
        var headerLen = UInt16(headerBytes.count).littleEndian
        withUnsafeBytes(of: &headerLen) { data.append(contentsOf: $0) }
        data.append(contentsOf: headerBytes)
        floats.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

extension AICaptureRecorder: ARSessionDelegate {
    nonisolated func session(_: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            guard self.recording else { return }
            self.frameCounter += 1
            // Subsample ~2 fps at 30 Hz to keep packages small for AirDrop.
            guard self.frameCounter % self.sampleEveryNFrames == 0 else { return }
            self.saveSample(from: frame)
        }
    }
}
