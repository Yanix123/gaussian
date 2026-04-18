import SwiftUI
import UIKit

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

        do {
            let jobId = try await client.createJob(images: state.capturedImages)

            state.jobId = jobId
            state.artifactURL =
            "http://192.168.1.2:8000/artifacts/\(jobId)/model.obj"

        } catch {
            state.lastError = error.localizedDescription
        }

        state.isUploading = false
    }
}
