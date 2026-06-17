import ARKit
import RealityKit
import SwiftUI
import UIKit

enum FigurePlacementIssue {
    case modelLoading
    case floorNotFound
}

struct ARViewContainer: UIViewRepresentable {
    let session: ARSession
    var placementResetToken: Int = 0
    var onFigurePlaced: () -> Void = {}
    var onPlacementIssue: (FigurePlacementIssue) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            session: session,
            onFigurePlaced: onFigurePlaced,
            onPlacementIssue: onPlacementIssue
        )
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.session = session
        context.coordinator.arView = arView
        context.coordinator.installTapGesture(on: arView)
        context.coordinator.preloadPlacementModelIfNeeded()
        applySceneSettings(to: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if uiView.session !== session {
            uiView.session = session
            context.coordinator.session = session
        }
        context.coordinator.onFigurePlaced = onFigurePlaced
        context.coordinator.onPlacementIssue = onPlacementIssue
        context.coordinator.clearPlacementIfNeeded(resetToken: placementResetToken)
        applySceneSettings(to: uiView)
    }

    private func applySceneSettings(to arView: ARView) {
        arView.environment.sceneUnderstanding.options = [.occlusion]
        arView.debugOptions = [.showFeaturePoints, .showSceneUnderstanding]
    }

    final class Coordinator: NSObject {
        private static let placementModelName = "CosmonautSuit_en"
        private static let placementFigureScale: Float = 0.35

        var session: ARSession
        var onFigurePlaced: () -> Void
        var onPlacementIssue: (FigurePlacementIssue) -> Void
        weak var arView: ARView?
        private var placedObjectAnchor: AnchorEntity?
        private var placementTemplate: Entity?
        private var isLoadingPlacementModel = false
        private var lastPlacementResetToken = 0

        init(
            session: ARSession,
            onFigurePlaced: @escaping () -> Void,
            onPlacementIssue: @escaping (FigurePlacementIssue) -> Void
        ) {
            self.session = session
            self.onFigurePlaced = onFigurePlaced
            self.onPlacementIssue = onPlacementIssue
        }

        func preloadPlacementModelIfNeeded() {
            guard placementTemplate == nil, !isLoadingPlacementModel else { return }
            isLoadingPlacementModel = true
            Task {
                defer { isLoadingPlacementModel = false }
                do {
                    let root = try await Entity(named: Self.placementModelName, in: Bundle.main)
                    placementTemplate = root
                    CaptureLog.capture.info("Placement scene loaded")
                } catch {
                    CaptureLog.capture.error("Placement scene load failed error=\(error.localizedDescription)")
                }
            }
        }

        func installTapGesture(on arView: ARView) {
            let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(gesture)
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, placedObjectAnchor == nil else { return }
            let location = gesture.location(in: arView)
            guard let raycastResult = raycast(at: location, in: arView) else {
                onPlacementIssue(.floorNotFound)
                return
            }
            placeFigure(from: raycastResult, in: arView)
        }

        func clearPlacementIfNeeded(resetToken: Int) {
            guard resetToken != lastPlacementResetToken else { return }
            lastPlacementResetToken = resetToken
            placedObjectAnchor?.removeFromParent()
            placedObjectAnchor = nil
        }

        private func raycast(at point: CGPoint, in arView: ARView) -> ARRaycastResult? {
            let targets: [ARRaycastQuery.Target] = [.existingPlaneGeometry, .estimatedPlane]
            for target in targets {
                let results = arView.raycast(from: point, allowing: target, alignment: .horizontal)
                if let first = results.first {
                    return first
                }
            }
            return nil
        }

        private func placeFigure(from raycastResult: ARRaycastResult, in arView: ARView) {
            guard let template = placementTemplate else {
                CaptureLog.capture.error("Placement scene not loaded yet")
                onPlacementIssue(.modelLoading)
                preloadPlacementModelIfNeeded()
                return
            }
            let anchor = AnchorEntity(world: raycastResult.worldTransform)
            let figure = template.clone(recursive: true)
            hideCosmonautSuit(in: figure)
            figure.scale = SIMD3(repeating: Self.placementFigureScale)
            alignFeetToGround(figure)
            anchor.addChild(figure)
            arView.scene.addAnchor(anchor)
            placedObjectAnchor = anchor
            CaptureLog.capture.info("Figure placed")
            onFigurePlaced()
        }

        private func hideCosmonautSuit(in root: Entity) {
            for child in root.children {
                let name = child.name.lowercased()
                if name.contains("cosmonaut") {
                    child.isEnabled = false
                }
            }
        }

        private func alignFeetToGround(_ entity: Entity) {
            let bounds = entity.visualBounds(relativeTo: nil)
            entity.position.y = -bounds.min.y
        }
    }
}
