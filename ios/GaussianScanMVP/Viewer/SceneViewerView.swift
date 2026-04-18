import SwiftUI

struct SceneViewerView: View {

    @EnvironmentObject var reconstructionState: ReconstructionState

    var body: some View {
        VStack {

            if reconstructionState.artifactURL != nil {
                SceneKitView()
                    .environmentObject(reconstructionState)
            } else {
                Text("Processing...")
            }
        }
    }
}
