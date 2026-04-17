import Foundation
import AppKit
import ApplicationServices

// MARK: - UI Automation Bridge
//
// Tools that Keynote's AppleScript dictionary does not expose natively.
// Every function drives the Keynote UI via System Events in a single
// AppleScript call so focus is never released between steps.

enum UIAutomationBridge {

    // MARK: - Shared Helpers

    /// Builds the Keynote-activate + navigate-to-slide preamble.
    private static func preamble(documentPath: String, slideIndex: Int?) -> String {
        let nav = slideIndex.map {
            "set current slide of theDoc to slide \($0) of theDoc\n        delay 0.3"
        } ?? ""
        return """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.5
            set theDoc to front document
            \(nav)
        end tell
        """
    }

    /// Builds a single-level menu click: Menu → Item.
    private static func menuClick(_ menu: String, item: String) -> String {
        """
        tell application "System Events"
            tell process "Keynote"
                click menu bar item "\(menu)" of menu bar 1
                delay 0.3
                click menu item "\(item)" of menu 1 of menu bar item "\(menu)" of menu bar 1
            end tell
        end tell
        """
    }

    /// Builds a two-level menu click: Menu → Parent → Child.
    private static func menuClickSub(_ menu: String, parent: String, child: String) -> String {
        """
        tell application "System Events"
            tell process "Keynote"
                click menu bar item "\(menu)" of menu bar 1
                delay 0.3
                click menu item "\(parent)" of menu 1 of menu bar item "\(menu)" of menu bar 1
                delay 0.3
                click menu item "\(child)" of menu 1 of menu item "\(parent)" of menu 1 of menu bar item "\(menu)" of menu bar 1
            end tell
        end tell
        """
    }

    /// Selects one or more items on a slide before a menu action.
    private static func selectObjects(documentPath: String, slideIndex: Int, objectIndexes: [Int]) -> String {
        let items = objectIndexes.map { "item \($0) of slide \(slideIndex)" }.joined(separator: ", ")
        return """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
            tell front document
                set current slide to slide \(slideIndex)
                set selection to {\(items)}
                delay 0.3
            end tell
        end tell
        """
    }

    // MARK: - Insert Tools

    /// Insert a named shape (Rectangle, Oval, Star, Triangle, etc.) onto a slide.
    static func insertShape(documentPath: String, slideIndex: Int, shapeName: String) throws -> String {
        let script = preamble(documentPath: documentPath, slideIndex: slideIndex) + "\n" +
            menuClickSub("Insert", parent: "Shape", child: shapeName)
        try AppleScriptRunner.run(script, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "\(shapeName) shape inserted on slide \(slideIndex)"
    }

    /// Insert a chart onto a slide (opens chart editor).
    static func insertChart(documentPath: String, slideIndex: Int) throws -> String {
        let script = preamble(documentPath: documentPath, slideIndex: slideIndex) + "\n" +
            menuClick("Insert", item: "Chart")
        try AppleScriptRunner.run(script, timeout: 15)
        return "Chart inserted on slide \(slideIndex) — edit data in the chart editor that opened"
    }

    /// Insert a line onto a slide.
    static func insertLine(documentPath: String, slideIndex: Int) throws -> String {
        let script = preamble(documentPath: documentPath, slideIndex: slideIndex) + "\n" +
            menuClick("Insert", item: "Line")
        try AppleScriptRunner.run(script, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Line inserted on slide \(slideIndex)"
    }

    /// Insert a web video (YouTube, Vimeo, etc.) by URL onto a slide.
    static func insertWebVideo(documentPath: String, slideIndex: Int, url: String) throws -> String {
        let safeURL = url.replacingOccurrences(of: "\"", with: "\\\"")
        let script = preamble(documentPath: documentPath, slideIndex: slideIndex) + """

        tell application "System Events"
            tell process "Keynote"
                click menu bar item "Insert" of menu bar 1
                delay 0.3
                click menu item "Web Video\u{2026}" of menu 1 of menu bar item "Insert" of menu bar 1
                delay 0.8
            end tell
            keystroke "\(safeURL)"
            delay 0.3
            key code 36
        end tell
        """
        try AppleScriptRunner.run(script, timeout: 20)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Web video '\(url)' inserted on slide \(slideIndex)"
    }

    /// Open the Record Audio dialog for the current slide.
    static func recordAudio(documentPath: String, slideIndex: Int) throws -> String {
        let script = preamble(documentPath: documentPath, slideIndex: slideIndex) + "\n" +
            menuClick("Insert", item: "Record Audio")
        try AppleScriptRunner.run(script, timeout: 15)
        return "Record Audio dialog opened on slide \(slideIndex) — press Record in Keynote, then stop when done"
    }

    // MARK: - Arrange Tools

    /// Change the z-order of the selected object: bring_to_front, bring_forward, send_to_back, send_backward.
    static func arrangeObject(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        action: String
    ) throws -> String {
        let itemName: String
        switch action.lowercased() {
        case "bring_to_front":  itemName = "Bring to Front"
        case "bring_forward":   itemName = "Bring Forward"
        case "send_to_back":    itemName = "Send to Back"
        case "send_backward":   itemName = "Send Backward"
        default: throw UIError.invalidArgument("action must be bring_to_front, bring_forward, send_to_back, or send_backward")
        }
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: [objectIndex])
        let click = menuClick("Arrange", item: itemName)
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Object \(objectIndex) on slide \(slideIndex): \(itemName)"
    }

    /// Align selected objects: left, center, right, top, middle, bottom.
    static func alignObjects(
        documentPath: String,
        slideIndex: Int,
        objectIndexes: [Int],
        alignment: String
    ) throws -> String {
        let itemName: String
        switch alignment.lowercased() {
        case "left":   itemName = "Left"
        case "center": itemName = "Center"
        case "right":  itemName = "Right"
        case "top":    itemName = "Top"
        case "middle": itemName = "Middle"
        case "bottom": itemName = "Bottom"
        default: throw UIError.invalidArgument("alignment must be left, center, right, top, middle, or bottom")
        }
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: objectIndexes)
        let click = menuClickSub("Arrange", parent: "Align Objects", child: itemName)
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Objects aligned \(alignment) on slide \(slideIndex)"
    }

    /// Distribute selected objects evenly: horizontal or vertical.
    static func distributeObjects(
        documentPath: String,
        slideIndex: Int,
        objectIndexes: [Int],
        direction: String
    ) throws -> String {
        let itemName: String
        switch direction.lowercased() {
        case "horizontal": itemName = "Evenly Spaced Horizontally"
        case "vertical":   itemName = "Evenly Spaced Vertically"
        default: throw UIError.invalidArgument("direction must be horizontal or vertical")
        }
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: objectIndexes)
        let click = menuClickSub("Arrange", parent: "Distribute Objects", child: itemName)
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Objects distributed \(direction)ly on slide \(slideIndex)"
    }

    /// Group or ungroup selected objects.
    static func groupObjects(
        documentPath: String,
        slideIndex: Int,
        objectIndexes: [Int],
        ungroup: Bool
    ) throws -> String {
        let action = ungroup ? "Ungroup" : "Group"
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: objectIndexes)
        let click = menuClick("Arrange", item: action)
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        try AppleScriptRunner.run("tell application \"Keynote\" to save front document", timeout: 10)
        return "Objects on slide \(slideIndex) \(action.lowercased())ed"
    }

    /// Lock or unlock the selected object.
    static func lockObject(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        lock: Bool
    ) throws -> String {
        let action = lock ? "Lock" : "Unlock"
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: [objectIndex])
        let click = menuClick("Arrange", item: action)
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        return "Object \(objectIndex) on slide \(slideIndex) \(action.lowercased())ed"
    }

    // MARK: - View Tools

    /// Switch Keynote view: navigator, light_table, outline, slide_only.
    static func setView(documentPath: String, view: String) throws -> String {
        let itemName: String
        switch view.lowercased() {
        case "navigator":   itemName = "Navigator"
        case "light_table": itemName = "Light Table"
        case "outline":     itemName = "Outline"
        case "slide_only":  itemName = "Slide Only"
        default: throw UIError.invalidArgument("view must be navigator, light_table, outline, or slide_only")
        }
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
        end tell
        """ + "\n" + menuClick("View", item: itemName)
        try AppleScriptRunner.run(script, timeout: 15)
        return "Keynote view switched to \(itemName)"
    }

    /// Show or hide the presenter notes panel.
    static func togglePresenterNotes(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
        end tell
        """ + "\n" + menuClick("View", item: "Show Presenter Notes")
        try AppleScriptRunner.run(script, timeout: 15)
        return "Presenter notes panel toggled"
    }

    // MARK: - Comments

    /// Add a comment to a specific object on a slide.
    static func addComment(documentPath: String, slideIndex: Int, objectIndex: Int, text: String) throws -> String {
        let safeText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let select = selectObjects(documentPath: documentPath, slideIndex: slideIndex, objectIndexes: [objectIndex])
        let click = """
        tell application "System Events"
            tell process "Keynote"
                click menu bar item "Insert" of menu bar 1
                delay 0.3
                click menu item "Comment" of menu 1 of menu bar item "Insert" of menu bar 1
                delay 0.5
            end tell
            keystroke "\(safeText)"
            delay 0.2
            key code 53
        end tell
        """
        try AppleScriptRunner.run(select + "\n" + click, timeout: 15)
        return "Comment added to object \(objectIndex) on slide \(slideIndex)"
    }

    /// Toggle the visibility of all comments in the document.
    static func toggleComments(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
        end tell
        """ + "\n" + menuClick("View", item: "Show Comments")
        try AppleScriptRunner.run(script, timeout: 10)
        return "Comments visibility toggled"
    }

    // MARK: - Animate Panel

    /// Open the Animate panel (required to add build-in/build-out animations to objects).
    static func openAnimatePanel(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
        end tell
        """ + "\n" + menuClick("View", item: "Animate")
        try AppleScriptRunner.run(script, timeout: 10)
        return "Animate panel opened — select an object in Keynote and click 'Add an Effect'"
    }

    // MARK: - Discovery Tool

    /// List all menu items in a given Keynote menu bar menu.
    static func listMenuItems(menuName: String) throws -> String {
        let script = """
        tell application "Keynote" to activate
        delay 0.3
        tell application "System Events"
            tell process "Keynote"
                set items to name of every menu item of menu 1 of menu bar item "\(menuName)" of menu bar 1
                return items
            end tell
        end tell
        """
        return try AppleScriptRunner.run(script, timeout: 10)
    }
}

// MARK: - UI Error

enum UIError: Error, LocalizedError {
    case invalidArgument(String)
    var errorDescription: String? {
        if case .invalidArgument(let msg) = self { return msg }
        return nil
    }
}
