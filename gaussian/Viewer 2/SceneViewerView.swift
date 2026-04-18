import SwiftUI
import SceneKit
import UIKit

struct SceneViewerView: View {

    @EnvironmentObject var reconstructionState: ReconstructionState

    var body: some View {
        VStack {
            if reconstructionState.artifactURL != nil {
                InlineSceneKitView()
                    .environmentObject(reconstructionState)
            } else if reconstructionState.isUploading || reconstructionState.jobStatus == "running" {
                ProgressView("Waiting for 3D artifact...")
            } else {
                if let error = reconstructionState.lastError {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    Text("No model yet")
                        .foregroundColor(.secondary)
                }
            }

            if let diagnostics = reconstructionState.viewerDiagnostics, !diagnostics.isEmpty {
                Text(diagnostics)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}

private struct InlineSceneKitView: UIViewRepresentable {
    @EnvironmentObject var reconstructionState: ReconstructionState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = .secondarySystemBackground
        view.scene = SCNScene()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let urlString = reconstructionState.artifactURL,
              let remoteURL = URL(string: urlString) else {
            uiView.scene = SCNScene()
            return
        }

        if context.coordinator.lastLoadedURL == remoteURL {
            return
        }
        context.coordinator.lastLoadedURL = remoteURL
        context.coordinator.loadTask?.cancel()

        let artifactDirectory = remoteURL.deletingLastPathComponent().lastPathComponent
        let assetDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scene_assets", isDirectory: true)
            .appendingPathComponent(artifactDirectory, isDirectory: true)
        try? FileManager.default.removeItem(at: assetDir)
        try? FileManager.default.createDirectory(at: assetDir, withIntermediateDirectories: true)

        context.coordinator.loadTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: remoteURL)
                let ext = remoteURL.pathExtension.isEmpty ? "obj" : remoteURL.pathExtension
                let localName = remoteURL.lastPathComponent.isEmpty ? "artifact.\(ext)" : remoteURL.lastPathComponent
                let localURL = assetDir.appendingPathComponent(localName)
                try data.write(to: localURL, options: .atomic)

                if ext.lowercased() == "obj" {
                    try await downloadObjSidecars(
                        objData: data,
                        remoteObjURL: remoteURL,
                        localDirectory: assetDir
                    )
                }

                let scene = try SCNScene(url: localURL, options: nil)
                if ext.lowercased() == "obj" {
                    let diagnostics = try applyRequiredTexture(scene: scene, localDirectory: assetDir)
                    await MainActor.run {
                        reconstructionState.viewerDiagnostics = diagnostics
                    }
                } else {
                    await MainActor.run {
                        reconstructionState.viewerDiagnostics = "Loaded scene format: .\(ext.lowercased())"
                    }
                }
                configureSceneForViewing(scene)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    reconstructionState.lastError = nil
                    uiView.scene = scene
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    reconstructionState.lastError = "VIEWER_LOAD_FAILED: \(error.localizedDescription)"
                    reconstructionState.viewerDiagnostics = "Artifact URL: \(remoteURL.absoluteString)"
                    uiView.scene = SCNScene()
                }
            }
        }
    }

    final class Coordinator {
        var lastLoadedURL: URL?
        var loadTask: Task<Void, Never>?
    }

    private func downloadObjSidecars(
        objData: Data,
        remoteObjURL: URL,
        localDirectory: URL
    ) async throws {
        guard let objText = String(data: objData, encoding: .utf8) else { return }
        guard let mtlName = parseMtlName(fromObj: objText) else { return }

        let remoteBase = remoteObjURL.deletingLastPathComponent()
        let remoteMtlURL = remoteBase.appendingPathComponent(mtlName)
        let localMtlURL = localDirectory.appendingPathComponent(mtlName)

        let (mtlData, mtlResponse) = try await URLSession.shared.data(from: remoteMtlURL)
        if let http = mtlResponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return
        }
        try mtlData.write(to: localMtlURL, options: .atomic)

        guard let mtlText = String(data: mtlData, encoding: .utf8) else { return }
        let textures = parseTextureNames(fromMtl: mtlText)
        for textureName in textures {
            let remoteTextureURL = remoteBase.appendingPathComponent(textureName)
            let localTextureURL = localDirectory.appendingPathComponent(textureName)
            do {
                let (textureData, textureResponse) = try await URLSession.shared.data(from: remoteTextureURL)
                if let http = textureResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                    try textureData.write(to: localTextureURL, options: .atomic)
                }
            } catch {
                // Texture is optional; keep OBJ loading even if sidecar is missing.
            }
        }
    }

    private func parseMtlName(fromObj text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("mtllib ") {
                return String(trimmed.dropFirst("mtllib ".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func parseTextureNames(fromMtl text: String) -> [String] {
        var names: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("map_Kd ") {
                let name = String(trimmed.dropFirst("map_Kd ".count)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    names.append(name)
                }
            }
        }
        return names
    }

    private func applyRequiredTexture(scene: SCNScene, localDirectory: URL) throws -> String {
        let candidates = ["albedo.jpg", "albedo.jpeg", "albedo.png", "albedo.webp"]
        let textureURL = candidates
            .map { localDirectory.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }

        guard let textureURL else {
            throw ViewerError.textureMissing("No albedo texture sidecar found near OBJ artifact")
        }
        guard let image = UIImage(contentsOfFile: textureURL.path) else {
            throw ViewerError.textureDecodeFailed("Failed to decode texture file: \(textureURL.lastPathComponent)")
        }

        var updatedMaterials = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            if geometry.materials.isEmpty {
                geometry.materials = [SCNMaterial()]
            }
            for index in geometry.materials.indices {
                let material = geometry.materials[index]
                material.diffuse.contents = image
                material.isDoubleSided = true
                material.lightingModel = .constant
                material.writesToDepthBuffer = true
                geometry.materials[index] = material
                updatedMaterials += 1
            }
        }

        if updatedMaterials == 0 {
            throw ViewerError.textureApplyFailed("OBJ loaded but no material slots found to apply texture")
        }
        return "Texture applied from \(textureURL.lastPathComponent) to \(updatedMaterials) materials"
    }

    private func configureSceneForViewing(_ scene: SCNScene) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            if geometry.materials.isEmpty {
                geometry.materials = [SCNMaterial()]
            }
            for index in geometry.materials.indices {
                let material = geometry.materials[index]
                material.writesToDepthBuffer = true
                if material.isDoubleSided == false {
                    material.isDoubleSided = true
                }
                geometry.materials[index] = material
            }
        }
        addOrUpdateLights(in: scene)
        fitCamera(to: scene)
    }

    private func addOrUpdateLights(in scene: SCNScene) {
        let lightNames = ["ambient_light", "key_light", "fill_light"]
        for name in lightNames {
            scene.rootNode.childNode(withName: name, recursively: false)?.removeFromParentNode()
        }

        let ambient = SCNNode()
        ambient.name = "ambient_light"
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.name = "key_light"
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 900
        key.position = SCNVector3(2.0, 2.0, 3.0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.name = "fill_light"
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 450
        fill.position = SCNVector3(-2.5, 1.2, -2.0)
        scene.rootNode.addChildNode(fill)
    }

    private func fitCamera(to scene: SCNScene) {
        let (minVec, maxVec) = scene.rootNode.boundingBox
        let size = SCNVector3(maxVec.x - minVec.x, maxVec.y - minVec.y, maxVec.z - minVec.z)
        let maxDimension = max(size.x, max(size.y, size.z))
        let radius = max(0.3, maxDimension * 0.7)
        let center = SCNVector3(
            (minVec.x + maxVec.x) * 0.5,
            (minVec.y + maxVec.y) * 0.5,
            (minVec.z + maxVec.z) * 0.5
        )

        let cameraNode: SCNNode
        if let existing = scene.rootNode.childNode(withName: "viewer_camera", recursively: false) {
            cameraNode = existing
        } else {
            cameraNode = SCNNode()
            cameraNode.name = "viewer_camera"
            let camera = SCNCamera()
            camera.fieldOfView = 55
            camera.zNear = 0.01
            camera.zFar = 500
            cameraNode.camera = camera
            scene.rootNode.addChildNode(cameraNode)
        }

        cameraNode.position = SCNVector3(center.x, center.y, center.z + radius * 3.2)
        cameraNode.look(at: center)
    }

    private enum ViewerError: LocalizedError {
        case textureMissing(String)
        case textureDecodeFailed(String)
        case textureApplyFailed(String)

        var errorDescription: String? {
            switch self {
            case .textureMissing(let message):
                return "TEXTURE_APPLY_FAILED: \(message)"
            case .textureDecodeFailed(let message):
                return "TEXTURE_APPLY_FAILED: \(message)"
            case .textureApplyFailed(let message):
                return "TEXTURE_APPLY_FAILED: \(message)"
            }
        }
    }
}
