import Foundation
import UniformTypeIdentifiers

protocol ModelImporting: Sendable {
    func listImportedModels(in directory: URL) throws -> [URL]
    func isSupportedModel(url: URL) -> Bool
    func copyIntoLibrary(from source: URL, libraryDirectory: URL) throws -> URL
}

/// Resolves imported GLB/USDZ/OBJ for the Results tab (files produced by Mac pipeline).
final class ModelImportService: ModelImporting, @unchecked Sendable {
    private let fileManager: FileManager

    /// Semantic legend colors match pipeline/room_pipeline/semantics.py LABEL_COLORS.
    static let semanticLegend: [(name: String, hex: String)] = [
        ("wall", "#BFBFCC"),
        ("floor", "#735940"),
        ("ceiling", "#E6E6F2"),
        ("door", "#995926"),
        ("window", "#59A6E6"),
        ("furniture", "#338C59"),
    ]

    static let supportedExtensions: Set<String> = ["glb", "usdz", "obj", "ply"]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isSupportedModel(url: URL) -> Bool {
        Self.supportedExtensions.contains(url.pathExtension.lowercased())
    }

    func listImportedModels(in directory: URL) throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { isSupportedModel(url: $0) }
            .sorted { lhs, rhs in
                let ld = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rd = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return ld > rd
            }
    }

    func copyIntoLibrary(from source: URL, libraryDirectory: URL) throws -> URL {
        try fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
        let dest = libraryDirectory.appendingPathComponent(source.lastPathComponent)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: source, to: dest)
        CaptureLog.ai.info("Imported model \(dest.lastPathComponent)")
        return dest
    }
}

extension UTType {
    static var glb: UTType {
        UTType(filenameExtension: "glb") ?? .data
    }
}
