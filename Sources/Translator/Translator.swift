import Foundation

final class Translator: TranslationServiceProtocol {
    private let apiKey: String
    private let session: URLSession
    private let baseURL = "https://api-free.deepl.com/v2/translate"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func translate(text: String, from source: Language, to target: Language) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ""
        }

        let components = URLComponents(string: baseURL)!
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let targetCode = target.deepLCode else {
            throw DeepLError.noTranslation
        }
        var bodyParts = [
            "text=\(escape(text))",
            "target_lang=\(targetCode)"
        ]
        if let sourceCode = source.deepLCode {
            bodyParts.append("source_lang=\(sourceCode)")
        }
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepLError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translations = json["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translatedText = first["text"] as? String else {
                throw DeepLError.noTranslation
            }
            return translatedText
        case 403:
            throw DeepLError.invalidKey
        case 429:
            throw DeepLError.rateLimited
        default:
            throw DeepLError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }

    private func escape(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}
