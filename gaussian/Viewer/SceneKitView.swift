import SceneKit
import SwiftUI

struct SceneKitView: UIViewRepresentable {
    @EnvironmentObject var reconstructionState: ReconstructionState

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = .secondarySystemBackground
        loadScene(into: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        loadScene(into: uiView)
    }

    private func loadScene(into view: SCNView) {
        guard let urlString = reconstructionState.artifactURL, let remote = URL(string: urlString) else {
            view.scene = fallbackScene()
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: remote)
                let ext = remote.pathExtension.isEmpty ? "obj" : remote.pathExtension
                let local = FileManager.default.temporaryDirectory.appendingPathComponent("artifact.\(ext)")
                try data.write(to: local, options: .atomic)
                let loaded = try SCNScene(url: local, options: nil)
                await MainActor.run {
                    view.scene = loaded
                }
            } catch {
                await MainActor.run {
                    reconstructionState.lastError = error.localizedDescription
                    view.scene = fallbackScene()
                }
            }
        }
    }

    private func fallbackScene() -> SCNScene {
        let scene = SCNScene()
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.05)
        box.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let node = SCNNode(geometry: box)
        scene.rootNode.addChildNode(node)
        return scene
    }
}
