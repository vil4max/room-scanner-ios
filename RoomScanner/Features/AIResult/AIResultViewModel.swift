import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AIResultViewModel {
    private let importer: any ModelImporting
    private let libraryDirectory: URL

    var models: [URL] = []
    var selectedModel: URL?
    var errorMessage: String?
    var isImporterPresented = false

    /// Legend text for diggable UI — matches Python semantic palette.
    var legend: [(name: String, hex: String)] {
        ModelImportService.semanticLegend
    }

    init(importer: any ModelImporting = ModelImportService(), libraryDirectory: URL? = nil) {
        self.importer = importer
        if let libraryDirectory {
            self.libraryDirectory = libraryDirectory
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.libraryDirectory = docs.appendingPathComponent("AIResults", isDirectory: true)
        }
    }

    func reload() {
        do {
            models = try importer.listImportedModels(in: libraryDirectory)
            if selectedModel == nil {
                selectedModel = models.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importFile(from url: URL) {
        errorMessage = nil
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        guard importer.isSupportedModel(url: url) else {
            errorMessage = "Unsupported type. Use glb, usdz, obj, or ply."
            return
        }
        do {
            let dest = try importer.copyIntoLibrary(from: url, libraryDirectory: libraryDirectory)
            reload()
            selectedModel = dest
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var allowedContentTypes: [UTType] {
        [.glb, .usdz, UTType(filenameExtension: "obj") ?? .data, UTType(filenameExtension: "ply") ?? .data]
    }
}
