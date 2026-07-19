import AppKit
import CoreGraphics

enum InstantLockShortcut {
    static let displayName = "Control–Option–Command–D"
    static let symbol = "⌃⌥⌘D"
    static let keyCode: CGKeyCode = 2

    private static let requiredFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    private static let relevantFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]

    static func matches(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        keyCode == self.keyCode && flags.intersection(relevantFlags) == requiredFlags
    }

    static func matches(event: NSEvent) -> Bool {
        matches(
            keyCode: CGKeyCode(event.keyCode),
            flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue))
        )
    }
}
