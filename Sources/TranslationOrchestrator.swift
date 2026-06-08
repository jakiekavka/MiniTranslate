import Cocoa

final class TranslationOrchestrator {
    private let translatorProvider: () throws -> TranslationServiceProtocol
    private let textAccessor: TextAccessor
    private let ocrReader: OCRReader
    private let screenshotOverlay: ScreenshotOverlay
    private let translationWindow: TranslationWindowController

    init(
        translatorProvider: @escaping () throws -> TranslationServiceProtocol,
        textAccessor: TextAccessor,
        ocrReader: OCRReader,
        screenshotOverlay: ScreenshotOverlay,
        translationWindow: TranslationWindowController
    ) {
        self.translatorProvider = translatorProvider
        self.textAccessor = textAccessor
        self.ocrReader = ocrReader
        self.screenshotOverlay = screenshotOverlay
        self.translationWindow = translationWindow

        translationWindow.onRetranslate = { [weak self] original, source, target in
            guard let self = self else { return "" }
            return try await self.translate(text: original, from: source, to: target)
        }
    }

    func handleTextTranslation() {
        // Move text access off main thread to avoid blocking UI during Cmd+C simulation
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            guard let text = self.textAccessor.getSelectedText(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                DispatchQueue.main.async {
                    self.translationWindow.show(original: "未检测到选中文本", translated: "请确认已选中文字", source: .auto, target: .chinese)
                }
                return
            }
            let target = Language.inferTarget(for: text)
            // Show window immediately with loading, then fetch translation
            DispatchQueue.main.async {
                self.translationWindow.show(original: text, translated: "", source: .auto, target: target, isLoading: true)
            }
            Task {
                do {
                    let result = try await self.translate(text: text, from: .auto, to: target)
                    await MainActor.run {
                        self.translationWindow.show(original: text, translated: result, source: .auto, target: target)
                    }
                } catch {
                    await MainActor.run {
                        self.translationWindow.show(original: text, translated: "", source: .auto, target: target)
                    }
                }
            }
        }
    }

    // MARK: - Screenshot Translation

    func handleScreenshotTranslation() {
        screenshotOverlay.capture { [weak self] image in
            guard let self = self, let image = image else { return }
            // Show window immediately with OCR loading hint
            DispatchQueue.main.async {
                self.translationWindow.show(original: "", translated: "", source: .auto, target: .chinese, isLoading: true, loadingHint: "正在识别文字...")
            }
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let ocrText = try await self.ocrReader.recognize(image: image)
                    guard !ocrText.trimmingCharacters(in: .whitespaces).isEmpty else {
                        await MainActor.run {
                            self.translationWindow.show(original: "未识别到文本", translated: "", source: .auto, target: .chinese)
                        }
                        return
                    }
                    let target = Language.inferTarget(for: ocrText)
                    // Show OCR result with translation loading hint
                    await MainActor.run {
                        self.translationWindow.show(original: ocrText, translated: "", source: .auto, target: target, isLoading: true, loadingHint: "正在翻译...")
                    }
                    let translation = try await self.translate(text: ocrText, from: .auto, to: target)
                    await MainActor.run {
                        self.translationWindow.show(original: ocrText, translated: translation, source: .auto, target: target)
                    }
                } catch {
                    await MainActor.run {
                        self.translationWindow.show(original: "OCR 识别失败", translated: "", source: .auto, target: .chinese)
                    }
                }
            }
        }
    }

    // MARK: - Translation

    private func translate(text: String, from source: Language, to target: Language) async throws -> String {
        if source.isTargetable && source == target {
            return "无需翻译"
        }
        let translator = try translatorProvider()
        return try await translator.translate(text: text, from: source, to: target)
    }
}
