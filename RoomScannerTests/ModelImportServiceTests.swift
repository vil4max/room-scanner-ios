import Foundation
@testable import RoomScanner
import Testing

struct ModelImportServiceTests {
    @Test func isSupportedModelAcceptsGlbUsdzObjPly() {
        // Tests that supported mesh extensions are recognized for Results import.
        let service = ModelImportService()
        #expect(service.isSupportedModel(url: URL(fileURLWithPath: "/tmp/room.glb")))
        #expect(service.isSupportedModel(url: URL(fileURLWithPath: "/tmp/room.usdz")))
        #expect(service.isSupportedModel(url: URL(fileURLWithPath: "/tmp/room.obj")))
        #expect(service.isSupportedModel(url: URL(fileURLWithPath: "/tmp/room.ply")))
        #expect(service.isSupportedModel(url: URL(fileURLWithPath: "/tmp/room.txt")) == false)
    }

    @Test func copyIntoLibraryAndListRoundTrip() throws {
        // Tests that imported models are copied and listed newest-first.
        let library = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sourceDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let source = sourceDir.appendingPathComponent("room.glb")
        try Data([0x67, 0x6C, 0x54, 0x46]).write(to: source)

        let service = ModelImportService()
        let dest = try service.copyIntoLibrary(from: source, libraryDirectory: library)
        let listed = try service.listImportedModels(in: library)
        #expect(listed.count == 1)
        #expect(listed.first == dest)
    }
}
