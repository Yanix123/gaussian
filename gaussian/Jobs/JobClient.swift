import UIKit

final class JobClient {
    struct JobCreateResponse {
        let jobId: String
        let status: String
        let artifactURL: String?
        let statusMessage: String?
        let failureReason: String?
    }

    let baseURL = AppConfig.backendBaseURL

    func createJob(images: [UIImage]) async throws -> JobCreateResponse {
        let url = baseURL.appendingPathComponent("jobs")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15 * 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        for (i, img) in images.enumerated() {
            let data = img.jpegData(compressionQuality: 0.9)!

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files\"; filename=\"img\(i).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.upload(for: request, from: body)
        } catch {
            throw mapNetworkError(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "GaussianScan", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let payload = String(data: data, encoding: .utf8) ?? "Server error"
            throw NSError(domain: "GaussianScan", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: payload])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GaussianScan", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }

        let jobId = (json["job_id"] as? String) ?? (json["jobId"] as? String) ?? ""
        if jobId.isEmpty {
            throw NSError(domain: "GaussianScan", code: 500, userInfo: [NSLocalizedDescriptionKey: "job_id not found"])
        }

        return JobCreateResponse(
            jobId: jobId,
            status: (json["status"] as? String) ?? "unknown",
            artifactURL: (json["artifact_url"] as? String) ?? (json["artifactUrl"] as? String),
            statusMessage: (json["status_message"] as? String) ?? (json["statusMessage"] as? String),
            failureReason: (json["failure_reason"] as? String) ?? (json["failureReason"] as? String)
        )
    }

    func getArtifactURL(jobId: String) async throws -> String? {
        let url = baseURL.appendingPathComponent("jobs").appendingPathComponent(jobId).appendingPathComponent("artifact")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return nil
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (json["artifact_url"] as? String) ?? (json["artifactUrl"] as? String) ?? (json["url"] as? String)
    }

    private func mapNetworkError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else {
            return error
        }

        if urlError.code == .timedOut {
            let helpText = "Request timed out while waiting for backend pipeline response at \(baseURL.absoluteString). Reconstruction can take several minutes in real mode. Keep backend running and try again with fewer photos or simulated mode for quick checks."
            return NSError(domain: "GaussianScan", code: urlError.errorCode, userInfo: [NSLocalizedDescriptionKey: helpText])
        }

        if urlError.code == .cannotConnectToHost || urlError.code == .cannotFindHost {
            let helpText: String
            if AppConfig.isUsingLocalhost && !AppConfig.isRunningOnSimulator {
                helpText = "Cannot connect to backend at \(baseURL.absoluteString). On physical iPhone, 127.0.0.1 points to the phone itself. Set GAUSSIAN_API_BASE_URL to your Mac IP, for example http://192.168.x.x:8000."
            } else {
                helpText = "Cannot connect to backend at \(baseURL.absoluteString). Ensure backend is running and reachable from the current device."
            }
            return NSError(domain: "GaussianScan", code: urlError.errorCode, userInfo: [NSLocalizedDescriptionKey: helpText])
        }

        return error
    }
}
