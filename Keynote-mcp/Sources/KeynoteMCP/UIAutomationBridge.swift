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

    /// Open the Animate panel by clicking the Animate (radio button 2) tab in the inspector.
    /// Works even if the View menu has no "Animate" item (Keynote 14+).
    static func openAnimatePanel(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.3
        end tell
        tell application "System Events"
            tell process "Keynote"
                set w to window 1
                -- The right inspector has 3 radio buttons: Format / Animate / Document
                -- Click button 2 (Animate)
                set rg to radio group 1 of w
                click radio button 2 of rg
                delay 0.5
            end tell
        end tell
        """
        try AppleScriptRunner.run(script, timeout: 10)
        return "Animate panel opened — select an object in Keynote and click 'Add an Effect'"
    }

    /// Add a build-in animation to a specific iWork item on a slide.
    /// Uses UI automation because Keynote's AppleScript dictionary does not expose build animations.
    /// effect: appear (default) | fade | move_in | wipe | shimmer | sparkle | pop
    /// buildBy: paragraph (default) | all_at_once
    static func addBuildAnimation(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        effect: String,
        buildBy: String?
    ) throws -> String {
        // Map effect to the Keynote UI menu name
        let effectName: String
        switch effect.lowercased() {
        case "fade":    effectName = "Fade In"
        case "move_in": effectName = "Move In"
        case "wipe":    effectName = "Wipe"
        case "shimmer": effectName = "Shimmer"
        case "sparkle": effectName = "Sparkle"
        case "pop":     effectName = "Pop"
        default:        effectName = "Appear"
        }

        let script = """
        -- 1. Activate Keynote, navigate to slide, select the item
        tell application "Keynote"
            activate
            open POSIX file "\(documentPath)"
            delay 0.5
            tell front document
                set current slide to slide \(slideIndex)
                delay 0.3
                set selection to {iWork item \(objectIndex) of slide \(slideIndex)}
                delay 0.5
            end tell
        end tell

        -- 2. Switch inspector to Animate tab (radio button 2)
        tell application "System Events"
            tell process "Keynote"
                set w to window 1
                set rg to radio group 1 of w
                click radio button 2 of rg
                delay 0.8
            end tell
        end tell

        -- 3. Find "Add an Effect" button — check direct window children first, then groups
        tell application "System Events"
            tell process "Keynote"
                set w to window 1
                set addBtn to missing value

                -- Primary: direct window buttons (confirmed location in Keynote 14+)
                repeat with b in every button of w
                    try
                        if title of b contains "Add" then
                            set addBtn to b
                            exit repeat
                        end if
                    end try
                end repeat

                -- Fallback: search 3 levels deep in groups
                if addBtn is missing value then
                    repeat with g1 in every group of w
                        if addBtn is missing value then
                            repeat with b in every button of g1
                                try
                                    if title of b contains "Add" then
                                        set addBtn to b
                                        exit repeat
                                    end if
                                end try
                            end repeat
                            if addBtn is missing value then
                                repeat with g2 in every group of g1
                                    if addBtn is missing value then
                                        repeat with b in every button of g2
                                            try
                                                if title of b contains "Add" then
                                                    set addBtn to b
                                                    exit repeat
                                                end if
                                            end try
                                        end repeat
                                        if addBtn is missing value then
                                            repeat with g3 in every group of g2
                                                repeat with b in every button of g3
                                                    try
                                                        if title of b contains "Add" then
                                                            set addBtn to b
                                                            exit repeat
                                                        end if
                                                    end try
                                                end repeat
                                            end repeat
                                        end if
                                    end if
                                end repeat
                            end if
                        end if
                    end repeat
                end if

                if addBtn is missing value then
                    return "Add an Effect button not found — ensure an object is selected and the Animate tab is visible in the inspector."
                end if

                -- 4. Click "Add an Effect" — opens effects chooser panel
                click addBtn
                delay 1.0

                -- 5. Find the effect in the chooser (scroll area with buttons/cells)
                set effectFound to false

                -- Look for named buttons in scroll areas (Keynote effects chooser)
                repeat with sa in every scroll area of w
                    repeat with b in every button of sa
                        try
                            if title of b contains "\(effectName)" then
                                click b
                                set effectFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                    if effectFound then exit repeat
                    -- Also check table rows (alternate layout)
                    try
                        set tbl to table 1 of sa
                        repeat with r in every row of tbl
                            repeat with c in every cell of r
                                try
                                    if value of static text 1 of c contains "\(effectName)" then
                                        click c
                                        set effectFound to true
                                        exit repeat
                                    end if
                                end try
                            end repeat
                            if effectFound then exit repeat
                        end repeat
                    end try
                    if effectFound then exit repeat
                end repeat

                -- Fallback: search all buttons in the window for the effect name
                if not effectFound then
                    repeat with b in every button of w
                        try
                            if title of b contains "\(effectName)" then
                                click b
                                set effectFound to true
                                exit repeat
                            end if
                        end try
                    end repeat
                end if

                delay 0.5

                if effectFound then
                    return "Build animation '\(effectName)' added to iWork item \(objectIndex) on slide \(slideIndex)"
                else
                    return "Clicked Add an Effect but could not find '\(effectName)' in the chooser. Animation panel is open in Keynote — select the effect manually."
                end if
            end tell
        end tell
        """
        return try AppleScriptRunner.run(script, timeout: 30)
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
