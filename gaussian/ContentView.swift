import SwiftUI

struct ContentView: View {
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
