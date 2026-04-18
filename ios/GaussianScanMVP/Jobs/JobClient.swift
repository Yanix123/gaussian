import UIKit

final class JobClient {

    let baseURL = URL(string: "http://192.168.1.2:8000")!

    func createJob(images: [UIImage]) async -> String? {

        let url = baseURL.appendingPathComponent("jobs")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

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

        do {
            let (data, _) = try await URLSession.shared.upload(for: request, from: body)

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["artifact_url"] as? String

        } catch {
            print("upload error:", error)
            return nil
        }
    }
}
