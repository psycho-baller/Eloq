import AppKit
import ApplicationServices
import Carbon
import Foundation
import Security

final class EloqKeychain {
    static let shared = EloqKeychain()

    private let preferredService = "io.eloq"
    private let fallbackService = "io.audora"
    private let apiKeyAccount = "openAIKey"

    private init() {}

    func openAIKey() -> String? {
        value(forKey: apiKeyAccount, service: preferredService)
            ?? value(forKey: apiKeyAccount, service: fallbackService)
    }

    @discardableResult
    func saveOpenAIKey(_ value: String) -> Bool {
        save(value, forKey: apiKeyAccount, service: preferredService)
    }

    @discardableResult
    func clearOpenAIKey() -> Bool {
        deleteValue(forKey: apiKeyAccount, service: preferredService)
    }

    private func save(_ value: String, forKey key: String, service: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
        ]

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private func value(forKey key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deleteValue(forKey key: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

@MainActor
final class EloqSelectionCaptureManager {
    static let shared = EloqSelectionCaptureManager()

    private init() {}

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func captureSelection(allowClipboardFallback: Bool = true) -> SelectionCaptureResult? {
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Current App"

        if isTrusted,
           let focusedElement = focusedElement(),
           let selectedText = copyStringAttribute(from: focusedElement, attribute: kAXSelectedTextAttribute as CFString),
           let normalized = Normalization.candidateTerm(selectedText) {
            return SelectionCaptureResult(
                text: normalized,
                sourceApp: sourceApp,
                contextLabel: sourceApp,
                usedClipboardFallback: false
            )
        }

        guard allowClipboardFallback,
              let clipboardText = NSPasteboard.general.string(forType: .string),
              let normalized = Normalization.candidateTerm(clipboardText) else {
            return nil
        }

        return SelectionCaptureResult(
            text: normalized,
            sourceApp: sourceApp,
            contextLabel: sourceApp,
            usedClipboardFallback: true
        )
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppRef: CFTypeRef?
        let appStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedAppRef
        )
        guard appStatus == .success, let focusedApp = focusedAppRef else {
            return nil
        }

        var focusedElementRef: CFTypeRef?
        let elementStatus = AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        guard elementStatus == .success, let focusedElement = focusedElementRef else {
            return nil
        }

        return (focusedElement as! AXUIElement)
    }

    private func copyStringAttribute(from element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else {
            return nil
        }

        return value as? String
    }
}

@MainActor
final class EloqGlobalHotKeyManager {
    private let signature = OSType(0x454C4F51)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onCapture: () -> Void

    init(onCapture: @escaping () -> Void) {
        self.onCapture = onCapture
        register()
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }

    private func register() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData else {
                return noErr
            }

            let manager = Unmanaged<EloqGlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.stride,
                nil,
                &hotKeyID
            )

            guard status == noErr, hotKeyID.signature == manager.signature else {
                return status
            }

            manager.onCapture()
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_L),
            UInt32(cmdKey | optionKey | controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotKeyRef = ref
    }
}
