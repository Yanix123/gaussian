import Foundation

enum AppConfig {
    // Use your Mac local IP when running backend for on-device testing.
    static let backendBaseURL = URL(string: ProcessInfo.processInfo.environment["GAUSSIAN_API_BASE_URL"] ?? "http://127.0.0.1:8000")!
}
