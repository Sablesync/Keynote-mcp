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

        // ── Step 2: Re-activate Keynote immediately before the menu click ──────
        // The terminal steals focus when Claude Code processes messages, so we
        // activate Keynote a second time right here and confirm focus before
        // sending any UI events.
        try AppleScriptRunner.run("""
        tell application "Keynote" to activate
        """, timeout: 5)
        try waitForKeynoteFocus(timeout: 5)

        // ── Step 3: Click Insert > Choose… via System Events ────────────────
        // Correct menu path in Keynote is Insert → Choose… (not "3D Object…").
        // Re-activate Keynote inside the same script block so focus is held
        // for the duration of the click — prevents the terminal from stealing it.
        // Try all known menu item name variants across Keynote versions.
        var menuClicked = false
        for itemName in ["Choose\u{2026}", "Choose...", "3D Object\u{2026}", "3D Object..."] {
            if (try? AppleScriptRunner.run("""
            tell application "Keynote" to activate
            tell application "System Events"
                tell process "Keynote"
                    click menu item "\(itemName)" of menu 1 of menu bar item "Insert" of menu bar 1
                end tell
            end tell
            """, timeout: 8)) != nil {
                menuClicked = true
                break
            }
        }
        guard menuClicked else {
            throw AccessibilityError.menuItemNotFound("Insert > Choose… — check the exact menu item name in your Keynote version")
        }

        // Give the file-picker sheet time to fully render before sending keys
        Thread.sleep(forTimeInterval: 2.5)

        // ── Step 4: Cmd+Shift+G → paste full path → Return twice ────────────
        // Pasting the full file path (not dir + filename separately) lets macOS
        // navigate to the parent folder AND pre-select the file in one step.
        try sendKeyCombo(key: 0x05, flags: [.maskCommand, .maskShift]) // Cmd+Shift+G
        Thread.sleep(forTimeInterval: 0.8)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(objectPath, forType: .string)
        try sendKeyCombo(key: 0x09, flags: .maskCommand) // Cmd+V — paste full path
        Thread.sleep(forTimeInterval: 0.5)

        try sendKey(key: 0x24) // Return — navigate and select file
        Thread.sleep(forTimeInterval: 1.2)

        try sendKey(key: 0x24) // Return — Insert
        Thread.sleep(forTimeInterval: 1.5)

        // ── Step 5: Save via AppleScript ────────────────────────────────────
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

