import Foundation
import UIKit
import Combine   // 🔥 ВАЖНО

final class ReconstructionState: ObservableObject {

    @Published var jobId: String? = nil
    @Published var jobStatus: String = "idle"
    @Published var statusMessage: String? = nil
    @Published var artifactURL: String? = nil

    @Published var capturedImages: [UIImage] = []
    @Published var isUploading: Bool = false

    @Published var lastError: String? = nil
    @Published var viewerDiagnostics: String? = nil
}
