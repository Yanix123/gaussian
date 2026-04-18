import SwiftUI

@main
struct GaussianScanMVPApp: App {

    @StateObject var reconstructionState = ReconstructionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(reconstructionState)
        }
    }
}
