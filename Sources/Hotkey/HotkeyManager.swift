import Cocoa
import Carbon

final class HotkeyManager {
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var handlerRef: EventHandlerRef?
    private var registrations: [(id: UInt32, action: () -> Void)] = []
    private var nextID: UInt32 = 1

    var isActive: Bool { !hotkeyRefs.isEmpty }

    func register(key: String, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        guard let keyCode = keyCode(for: key) else { return }
        var m: UInt32 = 0
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        if modifiers.contains(.option)  { m |= UInt32(optionKey) }
        if modifiers.contains(.shift)   { m |= UInt32(shiftKey) }
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        let id = nextID; nextID += 1
        var ref: EventHotKeyRef?
        let s = RegisterEventHotKey(UInt32(keyCode), m, EventHotKeyID(signature: 0x6D_74_72_6C, id: id), GetEventDispatcherTarget(), 0, &ref)
        if s == noErr, let r = ref { hotkeyRefs.append(r); registrations.append((id, action)) }
    }

    func start() {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var et = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let upp: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let ud = userData else { return OSStatus(eventNotHandledErr) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(ud).takeUnretainedValue()
            var hid = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hid) == noErr else { return noErr }
            for (id, action) in mgr.registrations where hid.id == id { DispatchQueue.main.async { action() }; break }
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(), upp, 1, &et, selfPtr, &handlerRef)
    }

    func stop() {
        if let r = handlerRef { RemoveEventHandler(r); handlerRef = nil }
        for r in hotkeyRefs { UnregisterEventHotKey(r) }
        hotkeyRefs.removeAll(); registrations.removeAll()
    }

    private func keyCode(for key: String) -> UInt16? {
        switch key.lowercased() { case "x": return UInt16(kVK_ANSI_X); case "z": return UInt16(kVK_ANSI_Z); default: return nil }
    }
}
