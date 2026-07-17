import ARKit
import SwiftUI

@main
struct RoomScannerApp: App {
    private let dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView(dependencies: dependencies)
        }
    }
}
