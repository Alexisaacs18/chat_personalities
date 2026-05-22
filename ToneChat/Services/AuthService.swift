import AuthenticationServices
import Foundation

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var isSignedInWithApple = false
    @Published var authError: String?
    @Published private(set) var isSessionReady = false

    private let baseURL: URL

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL
        super.init()
        isSignedInWithApple = KeychainHelper.readTier() == "apple"
        isSessionReady = KeychainHelper.readToken() != nil
    }

    func ensureSession() async throws {
        if KeychainHelper.readToken() != nil {
            isSignedInWithApple = KeychainHelper.readTier() == "apple"
            isSessionReady = true
            return
        }
        try await fetchGuestSession()
    }

    /// Clears a stale JWT (e.g. after server JWT_SECRET change) and issues a fresh guest session.
    func refreshSession() async throws {
        KeychainHelper.deleteToken()
        try await fetchGuestSession()
    }

    func bearerToken() async throws -> String {
        try await ensureSession()
        guard let token = KeychainHelper.readToken() else {
            throw ChatAPIError.unauthorized
        }
        return token
    }

    func signOut() async {
        KeychainHelper.deleteToken()
        isSignedInWithApple = false
        authError = nil
        do {
            try await fetchGuestSession()
        } catch {
            isSessionReady = false
            authError = error.localizedDescription
        }
    }

    #if DEBUG
    func signInDev() async {
        authError = nil
        do {
            var request = URLRequest(url: AppConfig.endpoint("/v1/auth/dev"))
            request.httpMethod = "POST"
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                authError = "Dev sign in failed. Start backend with ALLOW_DEV_AUTH=true."
                return
            }
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            applySession(token: decoded.token, tier: decoded.tier ?? "apple")
        } catch {
            authError = error.localizedDescription
        }
    }
    #endif

    func deleteAccount() async throws {
        guard isSignedInWithApple else { return }
        let token = try await bearerToken()
        var request = URLRequest(url: AppConfig.endpoint("/v1/account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        await signOut()
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleAuthorization(_ authorization: ASAuthorization) async {
        authError = nil
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            authError = "Could not read Apple identity token."
            return
        }

        do {
            var request = URLRequest(url: AppConfig.endpoint("/v1/auth/apple"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["identityToken": identityToken])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if let err = try? JSONDecoder().decode(ServerErrorBody.self, from: data),
                   let message = err.error, !message.isEmpty {
                    authError = message
                } else {
                    authError = "Sign in failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))."
                }
                return
            }
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            applySession(token: decoded.token, tier: decoded.tier ?? "apple")
        } catch {
            authError = error.localizedDescription
        }
    }

    private func fetchGuestSession() async throws {
        let deviceId = KeychainHelper.deviceId()
        var request = URLRequest(url: AppConfig.endpoint("/v1/auth/guest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["deviceId": deviceId])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        applySession(token: decoded.token, tier: decoded.tier ?? "guest")
    }

    private func applySession(token: String, tier: String) {
        KeychainHelper.saveToken(token, tier: tier)
        isSignedInWithApple = tier == "apple"
        isSessionReady = true
    }

    private struct AuthResponse: Decodable {
        let token: String
        let tier: String?
    }

    private struct ServerErrorBody: Decodable {
        let error: String?
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in await handleAuthorization(authorization) }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in authError = error.localizedDescription }
    }
}
