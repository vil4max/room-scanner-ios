import Foundation

protocol ScanSessionStoring: Sendable {
    func save(_ session: ScanSession) async throws
    func loadAll() async throws -> [ScanSession]
}

enum ScanSessionStoreError: Error {
    case encodingFailed
    case decodingFailed
}

final class ScanSessionStore: ScanSessionStoring, @unchecked Sendable {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.directoryURL = documents.appendingPathComponent("scans", isDirectory: true)
        }
    }

    func save(_ session: ScanSession) async throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("\(session.id.uuidString).json")
        guard let data = try? encoder.encode(session) else {
            throw ScanSessionStoreError.encodingFailed
        }
        try data.write(to: fileURL, options: .atomic)
        CaptureLog.capture.info("Session saved id=\(session.id.uuidString) path=\(fileURL.lastPathComponent)")
    }

    func loadAll() async throws -> [ScanSession] {
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            CaptureLog.capture.debug("Session load skipped: directory missing")
            return []
        }
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        var sessions: [ScanSession] = []
        sessions.reserveCapacity(urls.count)
        for url in urls {
            let data = try Data(contentsOf: url)
            guard let session = try? decoder.decode(ScanSession.self, from: data) else {
                throw ScanSessionStoreError.decodingFailed
            }
            sessions.append(session)
        }
        CaptureLog.capture.debug("Sessions loaded count=\(sessions.count)")
        return sessions.sorted { $0.createdAt > $1.createdAt }
    }
}
