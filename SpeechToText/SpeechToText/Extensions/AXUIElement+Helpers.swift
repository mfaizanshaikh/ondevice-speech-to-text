import Foundation
import AppKit

extension AXUIElement {
    static var systemWide: AXUIElement {
        AXUIElementCreateSystemWide()
    }

    static var focusedApplication: AXUIElement? {
        var app: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &app) == .success else {
            return nil
        }
        return (app as! AXUIElement)
    }

    static var focusedElement: AXUIElement? {
        guard let app = focusedApplication else { return nil }

        var element: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &element) == .success else {
            return nil
        }
        return (element as! AXUIElement)
    }

    func attribute<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? T
    }

    func setAttribute(_ attribute: String, value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
    }

    var role: String? {
        attribute(kAXRoleAttribute)
    }

    var title: String? {
        attribute(kAXTitleAttribute)
    }

    var value: Any? {
        attribute(kAXValueAttribute)
    }

    var selectedText: String? {
        attribute(kAXSelectedTextAttribute)
    }

    var selectedTextRange: CFRange? {
        guard let value: AXValue = attribute(kAXSelectedTextRangeAttribute) else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }
        return range
    }

    var isTextInput: Bool {
        guard let role = role else { return false }

        let textRoles = [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole
        ]

        return textRoles.contains(role)
    }

    func setSelectedText(_ text: String) -> Bool {
        setAttribute(kAXSelectedTextAttribute, value: text as CFTypeRef)
    }

    func setValue(_ newValue: String) -> Bool {
        setAttribute(kAXValueAttribute, value: newValue as CFTypeRef)
    }
}
