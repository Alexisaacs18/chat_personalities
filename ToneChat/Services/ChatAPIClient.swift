import Foundation

enum ChatAPIError: LocalizedError {
    case unauthorized
    case rateLimited
    case server(String)
    case connection(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Force-quit and reopen the app, or sign in again in Settings."
        case .rateLimited:
            return "Too many messages. Try again in a minute, or sign in with Apple for higher limits."
        case .server(let msg):
            return msg
        case .connection(let msg):
            return msg
        }
    }
}

struct ChatAPIClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    func streamChat(
        request: ChatRequest,
        auth: AuthService,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws {
        var token = try await auth.bearerToken()
        var urlRequest = try makeRequest(request: request, token: token)

        for attempt in 0..<2 {
            let result = try await startStream(urlRequest: urlRequest)

            if let http = result.response as? HTTPURLResponse,
               http.statusCode == 401 || http.statusCode == 500,
               attempt == 0 {
                KeychainHelper.deleteToken()
                token = try await auth.bearerToken()
                urlRequest = try makeRequest(request: request, token: token)
                continue
            }

            try await processStream(bytes: result.bytes, response: result.response, onDelta: onDelta)
            return
        }
    }

    private struct StreamResult {
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
    }

    private func startStream(urlRequest: URLRequest) async throws -> StreamResult {
        do {
            let (bytes, response) = try await session.bytes(for: urlRequest)
            return StreamResult(bytes: bytes, response: response)
        } catch {
            throw mapConnectionError(error)
        }
    }

    private func processStream(
        bytes: URLSession.AsyncBytes,
        response: URLResponse,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let http = response as? HTTPURLResponse else {
            throw ChatAPIError.server("Invalid response")
        }
        if http.statusCode == 401 { throw ChatAPIError.unauthorized }
        if http.statusCode == 429 { throw ChatAPIError.rateLimited }
        guard (200...299).contains(http.statusCode) else {
            let message = await readErrorMessage(from: bytes, statusCode: http.statusCode)
            throw ChatAPIError.server(message)
        }

        for try await line in bytes.lines {
            if Task.isCancelled { return }
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            guard !payload.isEmpty, let data = payload.data(using: .utf8) else { continue }
            guard let event = try? JSONDecoder().decode(StreamEvent.self, from: data) else { continue }

            switch event.type {
            case "delta":
                if let text = event.text, !text.isEmpty { onDelta(text) }
            case "error":
                throw ChatAPIError.server(sanitizeServerMessage(event.message ?? "Stream error"))
            case "done":
                return
            default:
                break
            }
        }
    }

    private func readErrorMessage(from bytes: URLSession.AsyncBytes, statusCode: Int) async -> String {
        var lines: [String] = []
        do {
            for try await line in bytes.lines {
                lines.append(line)
                if lines.count > 20 { break }
            }
        } catch {
            return "Server error (\(statusCode))"
        }

        let body = lines.joined(separator: "\n")
        if let data = body.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: String].self, from: data),
           let error = json["error"] {
            return sanitizeServerMessage(error)
        }
        if body.contains("invalid x-api-key") || body.contains("authentication") {
            return "Anthropic API key rejected. Check ANTHROPIC_API_KEY in ToneChatBackend/.env"
        }
        return body.isEmpty ? "Server error (\(statusCode))" : sanitizeServerMessage(String(body.prefix(300)))
    }

    private func sanitizeServerMessage(_ raw: String) -> String {
        if raw.contains("invalid x-api-key") || raw.contains("authentication_error") {
            return "Anthropic API key invalid. Update ANTHROPIC_API_KEY in ToneChatBackend/.env and restart the server."
        }
        if let data = raw.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: String].self, from: data),
           let error = json["error"] {
            return String(error.prefix(400))
        }
        return String(raw.prefix(400))
    }

    private func makeRequest(request: ChatRequest, token: String) throws -> URLRequest {
        var urlRequest = URLRequest(url: AppConfig.endpoint("/v1/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        return urlRequest
    }

    private func mapConnectionError(_ error: Error) -> ChatAPIError {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost:
                let host = baseURL.host ?? "server"
                if AppConfig.isLocalAPI {
                    return .connection(
                        "Cannot reach the server at \(host). " +
                        "TestFlight and physical devices need a deployed HTTPS API in Info.plist—not 127.0.0.1."
                    )
                }
                return .connection(
                    "Cannot reach the ToneChat server at \(host). " +
                    "Check your connection and that the API is deployed (https://chat-personalities.vercel.app/v1/health)."
                )
            case NSURLErrorTimedOut:
                return .connection("Request timed out. Check the server and API key.")
            default:
                break
            }
        }
        return .connection(error.localizedDescription)
    }
}
