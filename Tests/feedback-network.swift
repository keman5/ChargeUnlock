import Foundation

@main
struct FeedbackNetworkCheck {
    static func main() async throws {
        let id = UUID().uuidString.lowercased()
        let base = URL(string: "https://auv.macseek.cc")!
        func post(_ path: String, _ body: [String: Any]) async throws -> (Int, Data) {
            var request = URLRequest(url: base.appendingPathComponent(path))
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            return ((response as! HTTPURLResponse).statusCode, data)
        }
        let payload: [String: Any] = ["id": id, "message": "Synthetic URLSession integration verification, safe to delete.", "email": "", "consent": true]
        do {
            for _ in 0..<2 {
                let (status, data) = try await post("api/feedback", payload)
                guard status == 201 else { throw NSError(domain: "HTTP", code: status) }
                let receipt = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                precondition(receipt["id"] as? String == id)
            }
        } catch {
            _ = try? await post("api/feedback/delete", ["id": id])
            throw error
        }
        let (status, _) = try await post("api/feedback/delete", ["id": id])
        precondition(status == 200)
        print("URLSession HTTPS submission, identical retry and synthetic-record deletion passed")
    }
}
