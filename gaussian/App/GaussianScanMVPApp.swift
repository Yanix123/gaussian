import SwiftUI

@main
struct GaussianScanMVPApp: App {

    @StateObject var reconstructionState = ReconstructionState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(reconstructionState)
        }
    }
}

private struct RootView: View {
    var body: some View {
        TabView {
            GuidedCaptureView()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }

            SceneViewerView()
                .tabItem {
                    Label("Viewer", systemImage: "cube")
                }
        }
    }
}
