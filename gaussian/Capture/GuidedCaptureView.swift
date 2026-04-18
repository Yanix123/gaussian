import SwiftUI
import UIKit
import PhotosUI

struct GuidedCaptureView: View {

    @EnvironmentObject var state: ReconstructionState

    @State private var showPicker = false

    let client = JobClient()

    var body: some View {

        VStack(spacing: 20) {

            Text("Capture Photos")

            Button("Select Photos") {
                showPicker = true
            }

            Text("Selected: \(state.capturedImages.count)")

            Button("Start Reconstruction") {
                Task {
                    await upload()
                }
            }
            .disabled(state.capturedImages.isEmpty)

            if state.isUploading {
                ProgressView("Uploading...")
            }

            Text("Job status: \(state.jobStatus)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let message = state.statusMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let error = state.lastError {
                Text("Error: \(error)")
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            if let urlString = state.artifactURL {
                Text("Model ready:")
                Text(urlString)
                    .font(.caption)
            }

            Spacer()
        }
        .sheet(isPresented: $showPicker) {
            PhotoPicker(images: $state.capturedImages)
        }
        .padding()
    }

    private func upload() async {
        state.isUploading = true
        state.lastError = nil
        state.statusMessage = nil
        state.artifactURL = nil
        state.viewerDiagnostics = nil
        state.jobStatus = "running"

        do {
            let response = try await client.createJob(images: state.capturedImages)
            print("createJob response status=\(response.status) jobId=\(response.jobId) artifactURL=\(response.artifactURL ?? "nil") failure=\(response.failureReason ?? "nil")")
            state.jobId = response.jobId
            state.jobStatus = response.status
            state.statusMessage = response.statusMessage

            let status = response.status.lowercased()
            if status == "failed" || response.failureReason != nil {
                state.jobStatus = "failed"
                state.artifactURL = nil
                state.lastError = response.statusMessage ?? response.failureReason ?? "Reconstruction failed"
                state.isUploading = false
                return
            }

            var normalizedURL = response.artifactURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let candidate = normalizedURL, isUsableArtifactURL(candidate) {
                state.artifactURL = candidate
            } else {
                let fetched = try await client.getArtifactURL(jobId: response.jobId)
                normalizedURL = fetched?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let fetchedURL = normalizedURL, isUsableArtifactURL(fetchedURL) else {
                    state.jobStatus = "failed"
                    state.artifactURL = nil
                    state.lastError = "Artifact URL is missing or invalid in backend response"
                    state.isUploading = false
                    return
                }
                state.artifactURL = fetchedURL
            }
            state.lastError = nil
        } catch {
            state.jobStatus = "failed"
            state.lastError = error.localizedDescription
        }

        state.isUploading = false
    }

    private func isUsableArtifactURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else { return false }
        let ext = url.pathExtension.lowercased()
        return !ext.isEmpty && ["obj", "usdz", "ply", "splat", "glb"].contains(ext)
    }
}

private struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]

    func makeCoordinator() -> Coordinator {
        Coordinator(images: $images)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 120
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding private var images: [UIImage]

        init(images: Binding<[UIImage]>) {
            _images = images
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            images.removeAll()

            let group = DispatchGroup()
            var loaded: [UIImage] = []

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }
                        if let image = object as? UIImage {
                            loaded.append(image)
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.images = loaded
            }
        }
    }
}
