import Cocoa
import ApplicationServices

final class TextAccessor {
    func getSelectedText() -> String? {
        // Fast path: try AX tree first
        if let text = readViaAccessibilityTree() { return text }

        // Fallback: simulate Cmd+C via CGEvent (more reliable than AppleScript)
        return copyViaSimulatedCmdC()
    }

    private func readViaAccessibilityTree() -> String? {
        let sw = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sw, kAXFocusedApplicationAttribute as CFString, &appRef) == .success,
              let app = appRef else { return nil }

        // Start from focused element, walk up
        var elRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &elRef) == .success else { return nil }
        var current: AXUIElement? = (elRef as! AXUIElement)

        while let el = current {
            var textRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &textRef) == .success,
               let text = textRef as? String, !text.isEmpty { return text }
            var parentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parentRef) == .success {
                current = (parentRef as! AXUIElement)
            } else {
                break
            }
        }

        // Also try app window
        var winRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &winRef) == .success {
            var textRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(winRef as! AXUIElement, kAXSelectedTextAttribute as CFString, &textRef) == .success,
               let text = textRef as? String, !text.isEmpty { return text }
        }

        return nil
    }

    private func copyViaSimulatedCmdC() -> String? {
        let pb = NSPasteboard.general
        let oldChangeCount = pb.changeCount

        let src = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 0x08  // kVK_ANSI_C

        let down = CGEvent(keyboardEventSource: src, virtualKey: keyC, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: keyC, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)

        // Poll for pasteboard update up to 0.5s
        let deadline = Date().addingTimeInterval(0.5)
        while Date() < deadline {
            if pb.changeCount != oldChangeCount, let text = pb.string(forType: .string), !text.isEmpty {
                return text
            }
            Thread.sleep(forTimeInterval: 0.03)
        }
        return nil
    }
}
