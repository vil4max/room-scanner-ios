import ARKit
import SwiftUI

/// Root modes: keep Scan lab intact; add AI Capture + Results without a second app binary.
struct RootTabView: View {
    let dependencies: AppDependencies

    private var isLiDARMeshSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification)
    }

    var body: some View {
        TabView {
            NavigationStack {
                if isLiDARMeshSupported {
                    ScanView(
                        viewModel: dependencies.scanViewModel,
                        historyViewModel: dependencies.historyViewModel
                    )
                } else {
                    LiDARRequiredView()
                }
            }
            .tabItem {
                Label("Scan", systemImage: "cube.transparent")
            }

            NavigationStack {
                CaptureView(viewModel: dependencies.captureViewModel)
            }
            .tabItem {
                Label("AI Capture", systemImage: "record.circle")
            }

            NavigationStack {
                AIResultView(viewModel: dependencies.aiResultViewModel)
            }
            .tabItem {
                Label("Results", systemImage: "square.and.arrow.down.on.square")
            }
        }
        .preferredColorScheme(.dark)
    }
}
