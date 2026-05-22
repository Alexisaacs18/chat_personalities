import Foundation

/// Formats API usage-limit (429) responses for display in the chat UI.
enum UsageLimitMessage {
    private struct Payload: Decodable {
        let error: String?
        let message: String?
        let resetAt: String?
        let retryAfterSeconds: Int?
        let hint: String?
    }

    static func format(from data: Data) -> String {
        if let usage = parseUsageLimitPayload(data) {
            return usage
        }
        if let generic = parseGenericError(data) {
            return generic
        }
        let raw = String(data: data, encoding: .utf8) ?? ""
        if raw.hasPrefix("{") {
            return "You've maxed out your usage. Your usage will reset soon."
        }
        return raw.isEmpty ? fallback : raw
    }

    private static func parseUsageLimitPayload(_ data: Data) -> String? {
        if let payload = try? JSONDecoder().decode(Payload.self, from: data),
           isUsageLimit(payload) {
            return format(payload: payload)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let error = object["error"] as? String
        if error != "usage_limit", object["resetAt"] == nil, object["retryAfterSeconds"] == nil {
            return nil
        }

        return format(
            headline: object["message"] as? String,
            resetAt: object["resetAt"] as? String,
            retryAfterSeconds: object["retryAfterSeconds"] as? Int,
            hint: object["hint"] as? String,
            errorCode: error
        )
    }

    private static func parseGenericError(_ data: Data) -> String? {
        if let payload = try? JSONDecoder().decode(Payload.self, from: data),
           let message = payload.message, !message.isEmpty {
            return message
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? String,
           error != "usage_limit",
           !error.hasPrefix("{") {
            return error
        }
        return nil
    }

    private static func isUsageLimit(_ payload: Payload) -> Bool {
        payload.error == "usage_limit" || payload.resetAt != nil || payload.retryAfterSeconds != nil
    }

    private static func format(payload: Payload) -> String {
        format(
            headline: payload.message,
            resetAt: payload.resetAt,
            retryAfterSeconds: payload.retryAfterSeconds,
            hint: payload.hint,
            errorCode: payload.error
        )
    }

    private static func format(
        headline: String?,
        resetAt: String?,
        retryAfterSeconds: Int?,
        hint: String?,
        errorCode: String?
    ) -> String {
        var lines: [String] = []

        if let headline, !headline.isEmpty, headline != "usage_limit", !headline.hasPrefix("{") {
            lines.append(headline)
        } else if errorCode == "usage_limit" || resetAt != nil || retryAfterSeconds != nil {
            lines.append("You've maxed out your usage.")
        }

        if let resetAt, let date = parseISO8601(resetAt) {
            lines.append("Your usage will reset at \(formatResetTime(date)).")
        } else if let retryAfterSeconds, retryAfterSeconds > 0 {
            let date = Date().addingTimeInterval(TimeInterval(retryAfterSeconds))
            lines.append("Your usage will reset at \(formatResetTime(date)).")
        } else if errorCode == "usage_limit" {
            lines.append("Your usage will reset soon.")
        }

        if let hint = sanitizedHint(hint), !hint.isEmpty {
            lines.append(hint)
        }

        return lines.isEmpty ? fallback : lines.joined(separator: " ")
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func formatResetTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current

        if Calendar.current.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static let fallback =
        "You've maxed out your usage. Your usage will reset soon."

    /// Never surface dollar amounts or internal budget figures to the user.
    private static func sanitizedHint(_ hint: String?) -> String? {
        guard let hint, !hint.isEmpty else { return nil }
        if hint.contains("$") {
            if hint.localizedCaseInsensitiveContains("sign in with apple") {
                return "Sign in with Apple for higher limits."
            }
            return nil
        }
        return hint
    }
}
