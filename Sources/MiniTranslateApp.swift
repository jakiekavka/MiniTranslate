import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var hotkeyManager: HotkeyManager!
    private var orchestrator: TranslationOrchestrator!
    private var translator: TranslationServiceProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupOrchestrator()
        setupHotkeys()
        updateStatusTitle()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    private func updateStatusTitle() {
        statusItem.button?.image = makeMenuBarIcon(active: hotkeyManager.isActive)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = makeMenuBarIcon()
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func makeMenuBarIcon(active: Bool = true) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw rounded rect bubble background
        let bubbleRect = NSRect(x: 1, y: 1, width: 20, height: 16)
        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: 4, yRadius: 4)
        NSColor.controlTextColor.setFill()
        bubblePath.fill()

        // Cut out text using clear blend mode
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setBlendMode(.clear)
            let text = active ? "译" : "✕"
            let fontSize: CGFloat = active ? 11 : 12
            let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textOrigin = NSPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            text.draw(at: textOrigin, withAttributes: attributes)
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mini Translate 设置"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Orchestrator

    private func setupOrchestrator() {
        let translationWindow = TranslationWindowController()
        orchestrator = TranslationOrchestrator(
            translatorProvider: { [weak self] in
                guard let self = self else { throw DeepLError.invalidKey }
                return try self.getTranslator()
            },
            textAccessor: TextAccessor(),
            ocrReader: OCRReader(),
            screenshotOverlay: ScreenshotOverlay(),
            translationWindow: translationWindow
        )
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        hotkeyManager = HotkeyManager()

        hotkeyManager.register(key: "x", modifiers: [.control, .option]) { [weak self] in
            self?.orchestrator.handleTextTranslation()
        }

        hotkeyManager.register(key: "z", modifiers: [.control, .option]) { [weak self] in
            self?.orchestrator.handleScreenshotTranslation()
        }

        hotkeyManager.start()
    }

    // MARK: - Translator

    private func getTranslator() throws -> TranslationServiceProtocol {
        if let existing = translator { return existing }

        guard let apiKey = try KeychainStore.shared.read(), !apiKey.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
            throw DeepLError.invalidKey
        }

        let t = Translator(apiKey: apiKey)
        translator = t
        return t
    }
}
