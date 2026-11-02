import Carbon.HIToolbox

/// System-wide shortcuts. Carbon hot keys need no Accessibility permission and work in fullscreen apps too.
enum HotKeys {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef] = []
    private static var installed = false

    static let modifiers = UInt32(controlKey | optionKey | cmdKey)
    static let modifierSymbols = "⌃⌥⌘"

    static func register(keyCode: Int, modifiers: UInt32 = modifiers, _ action: @escaping () -> Void) {
        if !installed {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var id = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
                DispatchQueue.main.async { HotKeys.actions[id.id]?() }
                return noErr
            }, 1, &spec, nil, nil)
            installed = true
        }
        let id = UInt32(actions.count + 1)
        actions[id] = action
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(keyCode), modifiers, EventHotKeyID(signature: 0x4344_4D43, id: id),   // "CDMC"
                            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs.append(ref) }
    }
}
