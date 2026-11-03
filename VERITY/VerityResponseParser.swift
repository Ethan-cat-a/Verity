import Foundation

enum VerityResponseParser {
    static func assistantText(from data: Data) -> String {
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return raw }
        if let dictionary = object as? [String: Any] {
            for key in ["content", "response", "text", "output_text", "answer", "output"] {
                if let value = textValue(dictionary[key]), !value.isEmpty { return value }
            }
            if let message = dictionary["message"], let value = textValue(message), !value.isEmpty { return value }
            if let choices = dictionary["choices"] as? [[String: Any]], let first = choices.first {
                if let message = first["message"], let value = textValue(message), !value.isEmpty { return value }
                if let delta = first["delta"], let value = textValue(delta), !value.isEmpty { return value }
            }
            if let nested = dictionary["data"], let value = textValue(nested), !value.isEmpty { return value }
        }
        return ""
    }

    static func streamDelta(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let choices = object["choices"] as? [[String: Any]], let first = choices.first {
            if let delta = first["delta"], let text = textValue(delta), !text.isEmpty { return text }
            if let message = first["message"], let text = textValue(message), !text.isEmpty { return text }
        }
        if let delta = object["delta"], let text = textValue(delta), !text.isEmpty { return text }
        if let token = object["token"] as? String { return token }
        return ""
    }

    static func containsSensitiveInformation(_ text: String) -> Bool {
        let lower = text.lowercased()
        let indicators = ["password", "passcode", "one-time code", "verification code", "otp",
                          "credit card", "cvv", "api key", "secret key", "private key",
                          "access token", "refresh token", "recovery phrase", "seed phrase"]
        if indicators.contains(where: { lower.contains($0) }) { return true }
        let patterns = [
            #"(?i)\bsk-[A-Za-z0-9_-]{12,}\b"#,
            #"(?i)\bgh[pousr]_[A-Za-z0-9]{20,}\b"#,
            #"(?i)\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#,
            #"(?i)\bAKIA[0-9A-Z]{16}\b"#,
            #"(?i)\b(password|token|secret|api[_ -]?key)\s*[:=]\s*\S+"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private static func textValue(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let dictionary = value as? [String: Any] {
            for key in ["text", "content", "output_text", "response", "answer"] {
                if let result = textValue(dictionary[key]) { return result }
            }
        }
        if let items = value as? [Any] {
            let parts = items.compactMap { textValue($0) }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        }
        return nil
    }
}
