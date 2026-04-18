# iOS App Skeleton

SwiftUI reference structure for guided capture and Gaussian scene viewing.

## Modules

- `Capture/GuidedCaptureView.swift` capture UX with quality feedback
- `Capture/GuidedCaptureView.swift` includes real photo selection via PhotosPicker
- `Capture/FrameQualityEvaluator.swift` blur and exposure checks
- `Jobs/JobClient.swift` backend API integration
- `App/ReconstructionState.swift` shared capture/viewer app state
- `Viewer/SceneViewerView.swift` SceneKit-driven interactive viewer
- `Viewer/SceneKitContainerView.swift` SCNView bridge for SwiftUI
- `Viewer/WebSplatViewerView.swift` WKWebView-based `.splat` renderer

This directory is intentionally source-only so it can be dropped into an Xcode project.

If you create a fresh Xcode project, remove the default generated `@main` App file or replace it with `App/GaussianScanMVPApp.swift` to avoid duplicate `@main` errors.

When no final artifact is available yet, Viewer uses the selected real photo as a texture for interactive 3D preview.
