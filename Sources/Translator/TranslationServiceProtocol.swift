import Foundation

protocol TranslationServiceProtocol {
    func translate(text: String, from source: Language, to target: Language) async throws -> String
}
