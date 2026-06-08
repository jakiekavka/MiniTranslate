import Cocoa
import SwiftUI

final class TranslationWindowController {
    private var panel: NSPanel?
    private var currentText: (original: String, translated: String)?
    private var currentSource: Language = .auto
    private var currentTarget: Language = .chinese
    var onRetranslate: ((String, Language, Language) async throws -> String)?

    func show(original: String, translated: String, source: Language? = nil, target: Language? = nil, isLoading: Bool = false, loadingHint: String = "正在翻译...") {
        currentText = (original, translated)
        if let s = source { currentSource = s }
        if let t = target { currentTarget = t }

        if panel == nil {
            createPanel()
        }

        updateContent(isLoading: isLoading, loadingHint: loadingHint)
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
    }

    private func createPanel() {
        let prefs = TranslationView.loadLanguagePrefs()
        currentSource = prefs.source
        currentTarget = prefs.target

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 380),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Mini Translate"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false

        positionPanel(panel)
        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let x = screenFrame.maxX - panelFrame.width - 20
        let y = screenFrame.maxY - panelFrame.height - 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateContent(isLoading: Bool = false, loadingHint: String = "正在翻译...") {
        guard let panel = panel, let text = currentText else { return }

        let view = TranslationView(
            originalText: text.original,
            translatedText: text.translated,
            sourceLanguage: currentSource,
            targetLanguage: currentTarget,
            isLoading: isLoading,
            loadingHint: loadingHint
        ) { [weak self] newSource, newTarget in
            guard let self = self,
                  let onRetranslate = self.onRetranslate,
                  let original = self.currentText?.original else {
                return ""
            }
            self.currentSource = newSource
            self.currentTarget = newTarget
            return try await onRetranslate(original, newSource, newTarget)
        }

        panel.contentView = NSHostingView(rootView: view)
    }
}
