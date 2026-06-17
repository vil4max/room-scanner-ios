import os

enum CaptureLog {
    private static let subsystem = "com.vil4max.roomscanner"

    static let session = Logger(subsystem: subsystem, category: "ARSession")
    static let metrics = Logger(subsystem: subsystem, category: "Metrics")
    static let capture = Logger(subsystem: subsystem, category: "Capture")
}
