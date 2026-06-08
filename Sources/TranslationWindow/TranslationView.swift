import SwiftUI

struct TranslationView: View {
    let originalText: String
    @State var translatedText: String
    @State var sourceLanguage: Language
    @State var targetLanguage: Language
    @State private var isLoading: Bool
    @State private var loadingHint: String
    @State private var errorMessage: String?

    var onRetranslate: ((Language, Language) async throws -> String)?

    init(originalText: String, translatedText: String, sourceLanguage: Language, targetLanguage: Language, isLoading: Bool = false, loadingHint: String = "正在翻译...", onRetranslate: ((Language, Language) async throws -> String)? = nil) {
        self.originalText = originalText
        self._translatedText = State(initialValue: translatedText)
        self._sourceLanguage = State(initialValue: sourceLanguage)
        self._targetLanguage = State(initialValue: targetLanguage)
        self._isLoading = State(initialValue: isLoading)
        self._loadingHint = State(initialValue: loadingHint)
        self.onRetranslate = onRetranslate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            languageBar
            Divider()
            textSection(label: "原文", text: originalText)
            Divider()
            translatedSection
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button(action: copyAll) {
                    Label("复制", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                }
                .keyboardShortcut("c", modifiers: .command)
            }
        }
        .padding()
        .frame(minWidth: 360, minHeight: 260)
    }

    private var languageBar: some View {
        HStack(spacing: 6) {
            Picker("源语言", selection: $sourceLanguage) {
                ForEach(Language.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
            .onChange(of: sourceLanguage) { _ in retranslate() }

            Text("→")
                .foregroundColor(.secondary)

            Picker("目标语言", selection: $targetLanguage) {
                ForEach(Language.allCases.filter(\.isTargetable), id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)
            .onChange(of: targetLanguage) { _ in retranslate() }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private var translatedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("译文")
                .font(.caption)
                .foregroundColor(.secondary)
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(loadingHint)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            } else if let error = errorMessage {
                Text(error)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if sourceLanguage.isTargetable && sourceLanguage == targetLanguage {
                Text("无需翻译")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    Text(translatedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func textSection(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func copyAll() {
        let content = "\(originalText)\n---\n\(translatedText)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private func retranslate() {
        guard let onRetranslate = onRetranslate else { return }
        saveLanguagePrefs()
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await onRetranslate(sourceLanguage, targetLanguage)
                await MainActor.run {
                    translatedText = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = errorMessage(from: error)
                    isLoading = false
                }
            }
        }
    }

    private func errorMessage(from error: Error) -> String {
        if let deeplError = error as? DeepLError {
            switch deeplError {
            case .invalidKey: return "API Key 无效，请在设置中更新"
            case .networkError: return "无法连接至 DeepL"
            case .rateLimited: return "请求过于频繁，请稍后再试"
            case .noTranslation: return "翻译失败"
            }
        }
        return "翻译失败：\(error.localizedDescription)"
    }

    private func saveLanguagePrefs() {
        if let encoded = try? JSONEncoder().encode(sourceLanguage) {
            UserDefaults.standard.set(encoded, forKey: "sourceLanguage")
        }
        if let encoded = try? JSONEncoder().encode(targetLanguage) {
            UserDefaults.standard.set(encoded, forKey: "targetLanguage")
        }
    }

    static func loadLanguagePrefs() -> (source: Language, target: Language) {
        let source: Language = load(key: "sourceLanguage", default: .auto)
        let target: Language = load(key: "targetLanguage", default: .chinese)
        return (source, target)
    }

    private static func load<T: Decodable>(key: String, default: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return `default`
        }
        return value
    }
}
