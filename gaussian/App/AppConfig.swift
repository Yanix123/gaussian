import Foundation

enum AppConfig {
    // Use your Mac local IP when running backend for on-device testing.
    static let backendBaseURL = URL(string: ProcessInfo.processInfo.environment["GAUSSIAN_API_BASE_URL"] ?? "http://127.0.0.1:8000")!

    static var isUsingLocalhost: Bool {
        let host = backendBaseURL.host?.lowercased() ?? ""
        return host == "127.0.0.1" || host == "localhost"
    }

    static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
