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

        let filename = (objectPath as NSString).lastPathComponent
        let dir      = (objectPath as NSString).deletingLastPathComponent

        // ── Step 1: Activate Keynote and navigate to the target slide ─────────
        try AppleScriptRunner.run("""
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            tell front document
                set current slide to slide \(slideIndex)
            end tell
        end tell
        """, timeout: 20)

        // Wait until Keynote is confirmed frontmost (up to 5 s) before touching the UI
        try waitForKeynoteFocus(timeout: 5)

        // ── Step 2: Click Insert > 3D Object… via AX menu ──────────────────
        let axApp = try keynoteAXApp()
        try clickMenuItem(in: axApp, menu: "Insert", item: "3D Object\u{2026}")

        // Wait until the file-picker sheet appears (up to 5 s)
        try waitForFilePicker(timeout: 5)

        // ── Step 3: Open Go To Folder and paste path ────────────────────────
        // Use clipboard so paths with spaces work without escaping
        try sendKeyCombo(key: 0x05, flags: [.maskCommand, .maskShift]) // Cmd+Shift+G
        Thread.sleep(forTimeInterval: 0.6)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dir, forType: .string)
        try sendKeyCombo(key: 0x09, flags: .maskCommand) // Cmd+V — paste directory
        Thread.sleep(forTimeInterval: 0.3)

        try sendKey(key: 0x24) // Return — navigate to folder
        Thread.sleep(forTimeInterval: 1.0)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(filename, forType: .string)
        try sendKeyCombo(key: 0x09, flags: .maskCommand) // Cmd+V — paste filename
        Thread.sleep(forTimeInterval: 0.3)

        try sendKey(key: 0x24) // Return — Insert
        Thread.sleep(forTimeInterval: 1.5)

        // ── Step 4: Save via AppleScript ────────────────────────────────────
        try AppleScriptRunner.run("""
        tell application "Keynote"
            save front document in POSIX file "\(documentPath)"
        end tell
        """, timeout: 20)

        return "3D object '\(filename)' inserted on slide \(slideIndex) and saved."
    }

    // MARK: - AX Helpers

    /// Polls until Keynote is the frontmost app, or throws after `timeout` seconds.
    private static func waitForKeynoteFocus(timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.iWork.Keynote" {
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw AccessibilityError.axError(
            "Keynote did not become frontmost within \(Int(timeout))s. " +
            "Click on the Keynote window and retry."
        )
    }

    /// Polls until a file-picker window (NSOpenPanel) appears over Keynote, or throws after `timeout` seconds.
    private static func waitForFilePicker(timeout: TimeInterval) throws {
        let keynoteApp = try keynoteAXApp()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            var windowsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(keynoteApp, kAXWindowsAttribute as CFString, &windowsRef)
            if let windows = windowsRef as? [AXUIElement] {
                for window in windows {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &roleRef)
                    if let subrole = roleRef as? String, subrole == kAXDialogSubrole as String {
                        return
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        throw AccessibilityError.filePickerNotFound
    }

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

