import Cocoa

final class ScreenshotOverlay: NSObject {
    private var panels: [OverlayPanel] = []
    private var startPoint: NSPoint = .zero
    private var currentRect: NSRect = .zero
    private var isDragging = false
    private var completion: ((NSImage?) -> Void)?

    func capture(completion: @escaping (NSImage?) -> Void) {
        self.completion = completion

        for screen in NSScreen.screens {
            let panel = OverlayPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

            let overlayView = OverlayView(frame: screen.frame)
            overlayView.mouseDownHandler = { [weak self] point in
                self?.startPoint = point
                self?.currentRect = NSRect(origin: point, size: .zero)
                self?.isDragging = true
            }
            overlayView.mouseDraggedHandler = { [weak self] point in
                guard let self = self, self.isDragging else { return }
                let x = min(self.startPoint.x, point.x)
                let y = min(self.startPoint.y, point.y)
                let w = abs(point.x - self.startPoint.x)
                let h = abs(point.y - self.startPoint.y)
                self.currentRect = NSRect(x: x, y: y, width: w, height: h)
                for p in self.panels {
                    if let v = p.contentView as? OverlayView {
                        v.selectionRect = v.convert(self.currentRect, from: nil)
                    }
                }
            }
            overlayView.mouseUpHandler = { [weak self] in
                self?.finishCapture()
            }
            overlayView.escapeHandler = { [weak self] in
                self?.cancelCapture()
            }

            panel.contentView = overlayView
            panel.makeKeyAndOrderFront(nil)
            panels.append(panel)
        }

        NSCursor.crosshair.set()
    }

    private func finishCapture() {
        isDragging = false
        let rect = currentRect

        guard rect.width > 10 && rect.height > 10 else {
            dismissAll()
            completion?(nil)
            completion = nil
            return
        }

        dismissAll()
        NSCursor.arrow.set()
        usleep(500000)

        // Convert AppKit coords (origin bottom-left, Y up) to Quartz (origin top-left, Y down)
        let maxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let captureRect = CGRect(
            x: rect.minX,
            y: maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )

        guard let cgImage = CGWindowListCreateImage(captureRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            completion?(nil)
            completion = nil
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: rect.size)
        completion?(nsImage)
        completion = nil
    }

    private func cancelCapture() {
        dismissAll()
        NSCursor.arrow.set()
        completion?(nil)
        completion = nil
    }

    private func dismissAll() {
        for panel in panels {
            panel.alphaValue = 0
            panel.orderOut(nil)
        }
        panels.removeAll()
    }
}

// MARK: - Overlay Panel

private final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Overlay View

private final class OverlayView: NSView {
    var selectionRect: NSRect? { didSet { needsDisplay = true } }
    var mouseDownHandler: ((NSPoint) -> Void)?
    var mouseDraggedHandler: ((NSPoint) -> Void)?
    var mouseUpHandler: (() -> Void)?
    var escapeHandler: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.4).setFill()
        dirtyRect.fill()

        guard let sel = selectionRect, sel.width > 0, sel.height > 0 else { return }

        let fullPath = NSBezierPath(rect: bounds)
        let cutoutPath = NSBezierPath(rect: sel)
        fullPath.append(cutoutPath)
        fullPath.windingRule = .evenOdd
        fullPath.fill()

        NSColor.white.setStroke()
        let borderPath = NSBezierPath(rect: sel)
        borderPath.lineWidth = 1
        borderPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownHandler?(convert(event.locationInWindow, from: nil))
    }

    override func mouseDragged(with event: NSEvent) {
        mouseDraggedHandler?(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpHandler?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { escapeHandler?() }
        else { super.keyDown(with: event) }
    }

    override var acceptsFirstResponder: Bool { true }
}
