import Foundation
import CoreImage
import UIKit

struct FrameQualityResult {
    let blurScore: Double
    let exposureScore: Double
    let isAcceptable: Bool
}

enum FrameQualityEvaluator {
    static func evaluate(_ image: UIImage) -> FrameQualityResult {
        let blur = estimateBlur(image)
        let exposure = estimateExposure(image)
        let acceptable = blur > 100 && exposure > 0.25 && exposure < 0.85
        return FrameQualityResult(blurScore: blur, exposureScore: exposure, isAcceptable: acceptable)
    }

    private static func estimateBlur(_ image: UIImage) -> Double {
        // Placeholder metric for MVP: replace with Laplacian variance implementation.
        return Double(image.size.width + image.size.height) / 10
    }

    private static func estimateExposure(_ image: UIImage) -> Double {
        guard let cg = image.cgImage else { return 0.0 }
        let width = cg.width
        let height = cg.height
        let sample = max(1, (width * height) / 20000)
        return min(1.0, max(0.0, Double(sample) / 200.0))
    }
}
