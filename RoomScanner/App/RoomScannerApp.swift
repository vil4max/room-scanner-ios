import ARKit
import SwiftUI

@main
struct RoomScannerApp: App {
    private let dependencies = AppDependencies()

    private var isLiDARSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if isLiDARSupported {
                    ScanView(
                        viewModel: dependencies.scanViewModel,
                        historyViewModel: dependencies.historyViewModel
                    )
                } else {
                    LiDARRequiredView()
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
