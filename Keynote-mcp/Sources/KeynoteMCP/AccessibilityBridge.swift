import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

// MARK: - Accessibility Error

enum AccessibilityError: Error, LocalizedError {
    case permissionDenied
    case keynoteNotRunning
    case menuItemNotFound(String)
    case filePickerNotFound
    case fileNotFound(String)
    case axError(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return """
            Accessibility permission denied.
            Go to System Settings → Privacy & Security → Accessibility
            and enable your terminal app (iTerm2, Terminal, etc.), then retry.
            """
        case .keynoteNotRunning:
            return "Keynote is not running. Open the presentation first using open_presentation."
        case .menuItemNotFound(let name):
            return "Could not find menu item '\(name)' in Keynote. Make sure Keynote is frontmost."
        case .filePickerNotFound:
            return "File picker dialog did not appear after clicking Insert > 3D Object."
        case .fileNotFound(let path):
            return "3D object file not found: \(path)"
        case .axError(let msg):
            return "Accessibility error: \(msg)"
        }
    }
}

// MARK: - Accessibility Bridge

enum AccessibilityBridge {

    /// Insert a 3D object (USDZ/USDA/USDC) into a Keynote slide by:
    /// 1. Navigating to the target slide via AppleScript
    /// 2. Clicking Insert menu → "3D Object…" via AX
    /// 3. Typing the file path into the file picker's Go-to-folder sheet
    /// 4. Pressing Insert
    static func add3DObject(
        documentPath: String,
        slideIndex: Int,
        objectPath: String
    ) throws -> String {
        // ── Preflight ───────────────────────────────────────────────────────
        guard FileManager.default.fileExists(atPath: objectPath) else {
            throw AccessibilityError.fileNotFound(objectPath)
        }
        guard AXIsProcessTrusted() else {
            throw AccessibilityError.permissionDenied
        }

        // ── Step 1: Navigate to slide via AppleScript ───────────────────────
        let navScript = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            tell front document
                set current slide to slide \(slideIndex)
            end tell
        end tell
        """
        var navErr: NSDictionary?
        NSAppleScript(source: navScript)?.executeAndReturnError(&navErr)
        if let err = navErr {
            throw AccessibilityError.axError("Navigation failed: \(err[NSAppleScript.errorMessage] ?? err)")
        }
        Thread.sleep(forTimeInterval: 1.2)

        // ── Step 2: Click Insert > 3D Object… via AX menu ──────────────────
        let axApp = try keynoteAXApp()
        try clickMenuItem(in: axApp, menu: "Insert", item: "3D Object\u{2026}")
        // "3D Object…" uses the Unicode ellipsis character \u2026
        Thread.sleep(forTimeInterval: 1.0)

        // ── Step 3: In the file picker, use Cmd+Shift+G to open Go To Folder ─
        // The file picker (NSOpenPanel) is now frontmost.
        // We send Cmd+Shift+G to open the path entry sheet, type the path, confirm.
        try sendKeyCombo(key: 0x05, flags: [.maskCommand, .maskShift]) // Cmd+Shift+G = 'g'
        Thread.sleep(forTimeInterval: 0.6)

        // Type the directory of the file into the Go To Folder field
        let dir = (objectPath as NSString).deletingLastPathComponent
        let filename = (objectPath as NSString).lastPathComponent
        try typeString(dir)
        Thread.sleep(forTimeInterval: 0.3)

        // Press Return to navigate to the folder
        try sendKey(key: 0x24) // Return
        Thread.sleep(forTimeInterval: 0.8)

        // Type the filename to select it
        try typeString(filename)
        Thread.sleep(forTimeInterval: 0.4)

        // Press Return / click Insert to confirm
        try sendKey(key: 0x24) // Return
        Thread.sleep(forTimeInterval: 1.0)

        // ── Step 4: Save via AppleScript ────────────────────────────────────
        let saveScript = """
        tell application "Keynote"
            save front document in POSIX file "\(documentPath)"
        end tell
        """
        NSAppleScript(source: saveScript)?.executeAndReturnError(nil)

        return "3D object '\((objectPath as NSString).lastPathComponent)' inserted on slide \(slideIndex) and saved."
    }

    // MARK: - AX Helpers

    /// Get the AXUIElement for the running Keynote process.
    private static func keynoteAXApp() throws -> AXUIElement {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iWork.Keynote")
        guard let app = apps.first else { throw AccessibilityError.keynoteNotRunning }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    /// Walk the menu bar to find and press a specific menu item.
    private static func clickMenuItem(in app: AXUIElement, menu menuTitle: String, item itemTitle: String) throws {
        // Get menu bar
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef as! AXUIElement? else {
            throw AccessibilityError.menuItemNotFound("\(menuTitle) > \(itemTitle)")
        }

        // Get menu bar items
        var itemsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBar, kAXChildrenAttribute as CFString, &itemsRef)
        guard let menuBarItems = itemsRef as? [AXUIElement] else {
            throw AccessibilityError.menuItemNotFound(menuTitle)
        }

        // Find the target top-level menu (e.g. "Insert")
        var targetMenu: AXUIElement?
        for barItem in menuBarItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(barItem, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title == menuTitle {
                targetMenu = barItem
                break
            }
        }
        guard let menu = targetMenu else {
            throw AccessibilityError.menuItemNotFound(menuTitle)
        }

        // Press the top-level menu to open it
        AXUIElementPerformAction(menu, kAXPressAction as CFString)
        Thread.sleep(forTimeInterval: 0.4)

        // Get the opened submenu's children
        var submenuRef: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuRef)
        guard let submenus = submenuRef as? [AXUIElement], let submenu = submenus.first else {
            throw AccessibilityError.menuItemNotFound("\(menuTitle) submenu")
        }

        var subItemsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(submenu, kAXChildrenAttribute as CFString, &subItemsRef)
        guard let subItems = subItemsRef as? [AXUIElement] else {
            throw AccessibilityError.menuItemNotFound(itemTitle)
        }

        // Find and click the target menu item (e.g. "3D Object…")
        var found = false
        for subItem in subItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(subItem, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title == itemTitle {
                AXUIElementPerformAction(subItem, kAXPressAction as CFString)
                found = true
                break
            }
        }
        guard found else {
            // Close the menu and throw
            sendEscape()
            throw AccessibilityError.menuItemNotFound("\(menuTitle) > \(itemTitle)")
        }
    }

    // MARK: - CGEvent Key Helpers

    /// Send a key with modifier flags.
    private static func sendKeyCombo(key: CGKeyCode, flags: CGEventFlags) throws {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags   = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Send a plain key press (no modifiers).
    private static func sendKey(key: CGKeyCode) throws {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
    }

    /// Type a string character by character using CGEvent Unicode input.
    private static func typeString(_ string: String) throws {
        let src = CGEventSource(stateID: .hidSystemState)
        for char in string.unicodeScalars {
            var c = UniChar(char.value & 0xFFFF)
            let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
            up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &c)
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    /// Press Escape to dismiss a menu.
    private static func sendEscape() {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: 0x35, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: src, virtualKey: 0x35, keyDown: false)?.post(tap: .cghidEventTap)
    }
}

