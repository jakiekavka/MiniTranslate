import Foundation

enum DeepLError: Error, Equatable {
    case invalidKey
    case networkError(String)
    case rateLimited
    case noTranslation
}
