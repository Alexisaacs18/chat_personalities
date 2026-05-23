import Foundation

struct UsageSnapshot: Decodable, Equatable {
    let tier: String
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let percentUsed: Double
    let resetAt: String?

    var fractionUsed: Double {
        min(1, max(0, percentUsed / 100))
    }

    var resetDate: Date? {
        guard let resetAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetAt)
    }
}

@MainActor
final class UsageService: ObservableObject {
    @Published private(set) var usage: UsageSnapshot?
    @Published private(set) var isLoading = false
    @Published var loadError: String?

    func refresh(auth: AuthService) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let token = try await auth.bearerToken()
            var request = URLRequest(url: AppConfig.endpoint("/v1/usage"))
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                loadError = "Could not load usage"
                return
            }
            usage = try JSONDecoder().decode(UsageSnapshot.self, from: data)
        } catch {
            loadError = error.localizedDescription
        }
    }
}
