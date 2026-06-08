import Foundation

enum Language: String, CaseIterable, Codable {
    case auto
    case english
    case chinese
    case korean

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .english: return "English"
        case .chinese: return "中文"
        case .korean: return "한국어"
        }
    }

    var deepLCode: String? {
        switch self {
        case .auto: return nil
        case .english: return "EN"
        case .chinese: return "ZH"
        case .korean: return "KO"
        }
    }

    var isTargetable: Bool {
        self != .auto
    }

    /// Detect the best target language based on source text content.
    /// - Chinese text → English (so the user can read it)
    /// - Any other language → Chinese (so the user can read it)
    static func inferTarget(for text: String) -> Language {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .chinese }

        // Count characters in the CJK Unified Ideographs range
        let cjkPattern = try! NSRegularExpression(pattern: "[\\u4E00-\\u9FFF\\u3400-\\u4DBF\\uF900-\\uFAFF]")
        let cjkCount = cjkPattern.numberOfMatches(
            in: trimmed,
            range: NSRange(trimmed.startIndex..., in: trimmed)
        )

        // Total meaningful characters (exclude whitespace, control chars)
        let meaningfulChars = trimmed.filter { !$0.isWhitespace }.count
        guard meaningfulChars > 0 else { return .chinese }

        let ratio = Double(cjkCount) / Double(meaningfulChars)
        return ratio > 0.3 ? .english : .chinese
    }
}
