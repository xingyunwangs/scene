import Carbon
import Foundation

public final class GlobalHotKey {
    public typealias Handler = () -> Void

    private static var actions: [UInt32: Handler] = [:]
    private static var eventHandlerRef: EventHandlerRef?
    private static var handlerInstalled = false

    private var hotKeyRef: EventHotKeyRef?
    private let identifier: UInt32

    public init?(keyCode: UInt32, modifiers: UInt32, identifier: UInt32, handler: @escaping Handler) {
        self.identifier = identifier
        guard Self.installDispatcherIfNeeded() else { return nil }
        Self.actions[identifier] = handler

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            Self.actions.removeValue(forKey: identifier)
            NSLog("Sovereign hotkey registration failed: key=%u modifiers=%u status=%d", keyCode, modifiers, status)
            return nil
        }
        NSLog("Sovereign hotkey registered: key=%u modifiers=%u id=%u", keyCode, modifiers, identifier)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        Self.actions.removeValue(forKey: identifier)
    }

    private static func installDispatcherIfNeeded() -> Bool {
        guard !handlerInstalled else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ in
                guard let event else { return noErr }
                var eventID = EventHotKeyID()
                guard GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &eventID
                ) == noErr else { return noErr }
                GlobalHotKey.actions[eventID.id]?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        handlerInstalled = status == noErr
        if status != noErr {
            NSLog("Sovereign hotkey dispatcher installation failed: status=%d", status)
        }
        return handlerInstalled
    }

    private static let signature: OSType = {
        let bytes = Array("SVRN".utf8)
        return bytes.reduce(0) { ($0 << 8) | OSType($1) }
    }()
}
