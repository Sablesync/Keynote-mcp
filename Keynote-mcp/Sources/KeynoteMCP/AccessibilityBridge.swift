import Foundation
import AppKit
import ApplicationServices

// MARK: - Accessibility Error

enum AccessibilityError: Error, LocalizedError {
    case permissionDenied
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
        case .fileNotFound(let path):
            return "3D object file not found: \(path)"
        case .axError(let msg):
            return "Accessibility error: \(msg)"
        }
    }
}

// MARK: - Accessibility Bridge

enum AccessibilityBridge {

    /// Insert a 3D object (USDZ/USDA/USDC) into a Keynote slide.
    ///
    /// Everything runs inside a single AppleScript so focus is never released
    /// between steps — the root cause of previous failures.
    static func add3DObject(
        documentPath: String,
        slideIndex: Int,
        objectPath: String
    ) throws -> String {
        guard FileManager.default.fileExists(atPath: objectPath) else {
            throw AccessibilityError.fileNotFound(objectPath)
        }
        guard AXIsProcessTrusted() else {
            throw AccessibilityError.permissionDenied
        }

        let filename = (objectPath as NSString).lastPathComponent
        // Escape any double-quotes in paths for AppleScript string safety
        let safePath     = objectPath.replacingOccurrences(of: "\"", with: "\\\"")
        let safeDocPath  = documentPath.replacingOccurrences(of: "\"", with: "\\\"")

        // One monolithic AppleScript — no Swift-level sleeps, no CGEvent calls,
        // no clipboard tricks. AppleScript holds focus for its entire duration.
        try AppleScriptRunner.run("""
        -- Activate and navigate to the slide
        tell application "Keynote"
            activate
            open POSIX file "\(safeDocPath)"
            delay 0.5
            set theDoc to front document
            set current slide of theDoc to slide \(slideIndex) of theDoc
            delay 0.5
        end tell

        -- Two-step menu click: open the menu bar item first, then click the item.
        -- Doing both in one block keeps Keynote frontmost throughout.
        tell application "System Events"
            tell process "Keynote"
                click menu bar item "Insert" of menu bar 1
                delay 0.4
                click menu item "Choose..." of menu 1 of menu bar item "Insert" of menu bar 1
                delay 1
            end tell

            -- Open Go To Folder sheet and type the full file path
            keystroke "g" using {command down, shift down}
            delay 0.5
            keystroke "\(safePath)"
            delay 0.3
            key code 36 -- Return: navigate to the file
            delay 0.5
            key code 36 -- Return: confirm / Insert
            delay 1
        end tell
        """, timeout: 30)

        // Save after insertion
        try AppleScriptRunner.run("""
        tell application "Keynote"
            save front document in POSIX file "\(safeDocPath)"
        end tell
        """, timeout: 20)

        return "3D object '\(filename)' inserted on slide \(slideIndex) and saved."
    }
}
