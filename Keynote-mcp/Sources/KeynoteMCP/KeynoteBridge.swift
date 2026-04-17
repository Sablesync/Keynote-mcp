import Foundation

// MARK: - AppleScript Error

enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "AppleScript error: \(msg)"
        case .noResult: return "AppleScript returned no result"
        }
    }
}

// MARK: - AppleScript Runner

struct AppleScriptRunner {
    /// Runs an AppleScript with a timeout, returning the string result.
    /// Throws if the script fails or if Keynote blocks (e.g. shows a dialog) beyond the timeout.
    @discardableResult
    static func run(_ script: String, timeout: TimeInterval = 30) throws -> String {
        var result: String?
        var thrownError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            var errorDict: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            if let descriptor = appleScript?.executeAndReturnError(&errorDict) {
                result = descriptor.stringValue ?? ""
            } else {
                let message = (errorDict?[NSAppleScript.errorMessage] as? String)
                    ?? (errorDict?.description)
                    ?? "Unknown AppleScript error"
                thrownError = AppleScriptError.executionFailed(message)
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) != .timedOut else {
            throw AppleScriptError.executionFailed(
                "Keynote did not respond within \(Int(timeout))s — it may be showing a dialog. Check the screen and dismiss any open dialogs, then retry."
            )
        }

        if let error = thrownError { throw error }
        return result ?? ""
    }
}

// MARK: - Keynote Bridge

enum KeynoteBridge {

    // -------------------------------------------------------------------------
    // MARK: Create & Edit
    // -------------------------------------------------------------------------

    /// Create a new Keynote presentation with an optional theme.
    /// Returns the file path of the new document.
    static func createPresentation(title: String, theme: String?, outputPath: String) throws -> String {
        let dir = (outputPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let themeLine: String
        if let theme = theme, !theme.isEmpty {
            themeLine = "set the document theme of newDoc to theme \"\(theme)\""
        } else {
            themeLine = ""
        }

        let script = """
        tell application "Keynote"
            set newDoc to make new document with properties {name:"\(title)"}
            \(themeLine)
            save newDoc in POSIX file "\(outputPath)"
            return POSIX path of (file of newDoc as alias)
        end tell
        """
        let path = try AppleScriptRunner.run(script)
        return path.isEmpty ? outputPath : path
    }

    /// Add a slide at a given position (1-based). Layout can be "Title & Content", "Blank", etc.
    static func addSlide(documentPath: String, position: Int?, layout: String?) throws -> String {
        let positionLine = position.map { "at slide \($0)" } ?? ""
        let layoutLine = layout.map { "set base layout of newSlide to slide layout \"\($0)\"" } ?? ""

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set newSlide to make new slide \(positionLine)
                \(layoutLine)
                set slideIndex to slide number of newSlide
            end tell
            save front document
            return slideIndex as text
        end tell
        """
        let index = try AppleScriptRunner.run(script)
        return "Added slide at index \(index)"
    }

    /// Set the title and body text on a specific slide (1-based index).
    static func setSlideContent(documentPath: String, slideIndex: Int, title: String?, body: String?) throws -> String {
        var lines: [String] = []
        if let title = title {
            lines.append("set object text of default title item of slide \(slideIndex) to \"\(title)\"")
        }
        if let body = body {
            lines.append("set object text of default body item of slide \(slideIndex) to \"\(body)\"")
        }
        guard !lines.isEmpty else { return "Nothing to set" }

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                \(lines.joined(separator: "\n                "))
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Slide \(slideIndex) content updated"
    }

    /// Add a text box to a slide with specified text and optional position/size.
    /// Position is set AFTER text to avoid auto-resize offset issues.
    static func addTextBox(
        documentPath: String,
        slideIndex: Int,
        text: String,
        x: Double?, y: Double?,
        width: Double?, height: Double?
    ) throws -> String {
        let safeText = text.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
                          .replacingOccurrences(of: "\n", with: "\" & return & \"")
        let w = Int(width ?? 400)
        let h = Int(height ?? 100)
        let px = Int(x ?? 100)
        let py = Int(y ?? 100)

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    -- Create without position first; set text; then position (avoids auto-resize offset)
                    set tb to make new text item at end with properties {width:\(w), height:\(h)}
                    set object text of tb to "\(safeText)"
                    set position of tb to {\(px), \(py)}
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Text box added to slide \(slideIndex) at (\(px), \(py))"
    }

    /// Add an image to a slide from a file path.
    static func addImage(
        documentPath: String,
        slideIndex: Int,
        imagePath: String,
        x: Double?, y: Double?,
        width: Double?, height: Double?
    ) throws -> String {
        let posProps: String
        if let x = x, let y = y, let w = width, let h = height {
            posProps = "position:{x:\(Int(x)), y:\(Int(y))}, width:\(Int(w)), height:\(Int(h))"
        } else {
            posProps = "position:{x:100, y:100}"
        }

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set img to make new image with properties {\(posProps)}
                    set file of img to POSIX file "\(imagePath)"
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Image added to slide \(slideIndex)"
    }

    /// Add a video (MOV, MP4) to a slide with optional position, size, and playback settings.
    static func addVideo(
        documentPath: String,
        slideIndex: Int,
        videoPath: String,
        x: Double?, y: Double?,
        width: Double?, height: Double?,
        autoplay: Bool,
        loop: Bool
    ) throws -> String {
        let posProps: String
        if let x = x, let y = y, let w = width, let h = height {
            posProps = "position:{x:\(Int(x)), y:\(Int(y))}, width:\(Int(w)), height:\(Int(h))"
        } else {
            // Default: centered, 16:9 at comfortable size
            posProps = "position:{x:160, y:90}, width:960, height:540"
        }

        let autoplayStr = autoplay ? "true" : "false"
        let loopStr = loop ? "true" : "false"

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set vid to make new movie with properties {\(posProps)}
                    set file of vid to POSIX file "\(videoPath)"
                    set autoplay of vid to \(autoplayStr)
                    set loop of vid to \(loopStr)
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        let playback = "autoplay:\(autoplay) loop:\(loop)"
        return "Video added to slide \(slideIndex) (\(playback))"
    }

    /// Set the theme of an existing presentation.
    static func setTheme(documentPath: String, themeName: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            set document theme of front document to theme "\(themeName)"
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Theme set to \"\(themeName)\""
    }

    // -------------------------------------------------------------------------
    // MARK: Read
    // -------------------------------------------------------------------------

    /// Get high-level info about a presentation: slide count, theme, name.
    static func getPresentationInfo(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set docName to name
                set slideCount to count of slides
                set themeName to name of document theme
                return "name:" & docName & "|slides:" & slideCount & "|theme:" & themeName
            end tell
        end tell
        """
        let raw = try AppleScriptRunner.run(script)
        // Parse the pipe-separated result into readable JSON-ish text
        let parts = raw.split(separator: "|").map(String.init)
        return parts.joined(separator: "\n")
    }

    /// List all slides with their index and title.
    static func listSlides(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set output to ""
                repeat with i from 1 to count of slides
                    set s to slide i
                    set slideTitle to ""
                    try
                        set slideTitle to object text of default title item of s
                    end try
                    set output to output & i & ":" & slideTitle & "|"
                end repeat
                return output
            end tell
        end tell
        """
        let raw = try AppleScriptRunner.run(script)
        let slides = raw.split(separator: "|").map(String.init).filter { !$0.isEmpty }
        return slides.map { "Slide \($0)" }.joined(separator: "\n")
    }

    /// Get detailed content of a specific slide.
    static func getSlideContent(documentPath: String, slideIndex: Int) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set titleText to ""
                    set bodyText to ""
                    set notes to presenter notes
                    try
                        set titleText to object text of default title item
                    end try
                    try
                        set bodyText to object text of default body item
                    end try
                    return "title:" & titleText & "|body:" & bodyText & "|notes:" & notes
                end tell
            end tell
        end tell
        """
        let raw = try AppleScriptRunner.run(script)
        let parts = raw.split(separator: "|").map(String.init)
        return parts.joined(separator: "\n")
    }

    // -------------------------------------------------------------------------
    // MARK: Run & Export
    // -------------------------------------------------------------------------

    /// Open a Keynote file (brings it to front).
    static func openPresentation(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            activate
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Opened \(documentPath)"
    }

    /// Start the slideshow for the front document.
    static func startSlideshow(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            start the front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Slideshow started"
    }

    /// Stop the running slideshow.
    static func stopSlideshow() throws -> String {
        let script = """
        tell application "Keynote"
            stop the front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Slideshow stopped"
    }

    /// Export a presentation to PDF, PowerPoint, or images.
    /// format: "PDF", "Microsoft PowerPoint", "HTML", "QuickTime Movie"
    static func exportPresentation(
        documentPath: String,
        exportPath: String,
        format: String
    ) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            export front document to POSIX file "\(exportPath)" as \(format)
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Exported to \(exportPath) as \(format)"
    }

    // -------------------------------------------------------------------------
    // MARK: Bulk Read (performance)
    // -------------------------------------------------------------------------

    /// Get ALL slides in a single AppleScript round-trip.
    /// Use this instead of calling get_slide_content N times — far faster.
    static func getAllSlides(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set slideCount to count of slides
                set output to "slide_count:" & slideCount & "\n"
                repeat with i from 1 to slideCount
                    set s to slide i
                    set titleText to ""
                    set bodyText to ""
                    set slideNotes to ""
                    try
                        set titleText to object text of default title item of s
                    end try
                    try
                        set bodyText to object text of default body item of s
                    end try
                    try
                        set slideNotes to presenter notes of s
                    end try
                    set output to output & "---SLIDE:" & i & "\n"
                    set output to output & "title:" & titleText & "\n"
                    set output to output & "body:" & bodyText & "\n"
                    set output to output & "notes:" & slideNotes & "\n"
                end repeat
                return output
            end tell
        end tell
        """
        return try AppleScriptRunner.run(script)
    }

    // -------------------------------------------------------------------------
    // MARK: Explicit Save
    // -------------------------------------------------------------------------

    // -------------------------------------------------------------------------
    // MARK: New Tools
    // -------------------------------------------------------------------------

    /// List all installed Keynote themes by name.
    static func listThemes() throws -> String {
        let script = """
        tell application "Keynote"
            set output to ""
            repeat with t in themes
                set output to output & name of t & "\n"
            end repeat
            return output
        end tell
        """
        let raw = try AppleScriptRunner.run(script)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Delete a slide at the given 1-based index.
    static func deleteSlide(documentPath: String, slideIndex: Int) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                delete slide \(slideIndex)
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Slide \(slideIndex) deleted"
    }

    /// Duplicate a slide at the given 1-based index.
    static func duplicateSlide(documentPath: String, slideIndex: Int) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set newSlide to duplicate slide \(slideIndex)
                return slide number of newSlide as text
            end tell
        end tell
        """
        let newIndex = try AppleScriptRunner.run(script)
        try AppleScriptRunner.run("""
        tell application "Keynote"
            save front document
        end tell
        """)
        return "Slide \(slideIndex) duplicated as slide \(newIndex)"
    }

    /// Set the presenter notes on a specific slide.
    static func setPresenterNotes(documentPath: String, slideIndex: Int, notes: String) throws -> String {
        let escaped = notes.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set presenter notes of slide \(slideIndex) to "\(escaped)"
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Presenter notes set on slide \(slideIndex)"
    }

    /// Set the slide transition. Effect names: magic move, dissolve, push, wipe, reveal, cube,
    /// flip, shimmer, sparkle, swing, fall, confetti, mosaic, page flip, pivot, etc.
    static func setSlideTransition(
        documentPath: String,
        slideIndex: Int,
        effect: String,
        duration: Double?,
        direction: String?
    ) throws -> String {
        var props = "transition effect:\(effect)"
        if let d = duration { props += ", transition duration:\(d)" }
        if let dir = direction { props += ", transition direction:\(dir)" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set transition properties of slide \(slideIndex) to {\(props)}
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Transition '\(effect)' set on slide \(slideIndex)"
    }

    /// Set document-level properties: slide_numbers_showing, auto_loop, auto_play,
    /// auto_restart, max_idle_duration, width, height.
    static func setDocumentProperties(
        documentPath: String,
        slideNumbersShowing: Bool?,
        autoLoop: Bool?,
        autoPlay: Bool?,
        autoRestart: Bool?,
        maxIdleDuration: Int?,
        width: Int?,
        height: Int?
    ) throws -> String {
        var lines: [String] = []
        if let v = slideNumbersShowing { lines.append("set slide numbers showing to \(v)") }
        if let v = autoLoop           { lines.append("set auto loop to \(v)") }
        if let v = autoPlay           { lines.append("set auto play to \(v)") }
        if let v = autoRestart        { lines.append("set auto restart to \(v)") }
        if let v = maxIdleDuration    { lines.append("set maximum idle duration to \(v)") }
        if let v = width              { lines.append("set width to \(v)") }
        if let v = height             { lines.append("set height to \(v)") }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                \(lines.joined(separator: "\n                "))
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Document properties updated: \(lines.joined(separator: ", "))"
    }

    /// Mark or unmark a slide as skipped.
    static func skipSlide(documentPath: String, slideIndex: Int, skip: Bool) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set skipped of slide \(slideIndex) to \(skip)
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Slide \(slideIndex) \(skip ? "marked as skipped" : "unskipped")"
    }

    /// Advance to the next slide during a running slideshow.
    static func showNextSlide(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            show next of front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Advanced to next slide"
    }

    /// Go back to the previous slide during a running slideshow.
    static func showPreviousSlide(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            show previous of front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Went back to previous slide"
    }

    /// Bulk-create slides from a list of image file paths.
    static func makeImageSlides(documentPath: String, imagePaths: [String]) throws -> String {
        let fileList = imagePaths.map { "POSIX file \"\($0)\"" }.joined(separator: ", ")
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            make image slides from front document image files {\(fileList)}
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Created \(imagePaths.count) image slide(s)"
    }

    /// Move and/or resize the Nth object on a slide (1-based object index).
    static func setObjectPosition(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        x: Double?, y: Double?,
        width: Double?, height: Double?,
        rotation: Double?
    ) throws -> String {
        var lines: [String] = []
        if let x = x, let y = y { lines.append("set position of item \(objectIndex) to {\(Int(x)), \(Int(y))}") }
        if let w = width         { lines.append("set width of item \(objectIndex) to \(Int(w))") }
        if let h = height        { lines.append("set height of item \(objectIndex) to \(Int(h))") }
        if let r = rotation      { lines.append("set rotation of item \(objectIndex) to \(r)") }
        guard !lines.isEmpty else { return "Nothing to change" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Object \(objectIndex) on slide \(slideIndex) updated"
    }

    // -------------------------------------------------------------------------
    // MARK: Text & Object Styling
    // -------------------------------------------------------------------------

    /// Set font name, size, and/or color on a specific shape's text.
    /// Color values are 0–255 RGB.
    static func setTextStyle(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        fontName: String?,
        fontSize: Double?,
        colorR: Int?, colorG: Int?, colorB: Int?
    ) throws -> String {
        var lines: [String] = []
        if let f = fontName { lines.append("set font to \"\(f)\"") }
        if let s = fontSize { lines.append("set size to \(s)") }
        if let r = colorR, let g = colorG, let b = colorB {
            lines.append("set color to {\(r * 257), \(g * 257), \(b * 257)}")
        }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    tell object text of shape \(objectIndex)
                        \(lines.joined(separator: "\n                        "))
                    end tell
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Text style updated on slide \(slideIndex) shape \(objectIndex)"
    }

    /// Set the opacity (0–100) of an object on a slide.
    static func setObjectOpacity(documentPath: String, slideIndex: Int, objectIndex: Int, opacity: Int) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set opacity of item \(objectIndex) of slide \(slideIndex) to \(opacity)
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Object \(objectIndex) opacity set to \(opacity)%"
    }

    /// Enable/disable reflection on an object and set its value (0–100).
    static func setObjectReflection(
        documentPath: String,
        slideIndex: Int,
        objectIndex: Int,
        showing: Bool,
        value: Int?
    ) throws -> String {
        var lines = ["set reflection showing of item \(objectIndex) to \(showing)"]
        if let v = value { lines.append("set reflection value of item \(objectIndex) to \(v)") }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Reflection \(showing ? "enabled" : "disabled") on object \(objectIndex)"
    }

    /// Set same transition on every slide in the presentation.
    static func setAllTransitions(
        documentPath: String,
        effect: String,
        duration: Double?,
        autoTransition: Bool?
    ) throws -> String {
        var props = "transition effect:\(effect)"
        if let d = duration { props += ", transition duration:\(d)" }
        if let a = autoTransition { props += ", automatic transition:\(a)" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                repeat with s in slides
                    set transition properties of s to {\(props)}
                end repeat
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Transition '\(effect)' applied to all slides"
    }

    // -------------------------------------------------------------------------
    // MARK: Tables
    // -------------------------------------------------------------------------

    /// Set the value of a table cell (row and column are 1-based).
    static func setTableCell(
        documentPath: String,
        slideIndex: Int,
        tableIndex: Int,
        row: Int,
        column: Int,
        value: String
    ) throws -> String {
        let valueExpr = Double(value) != nil ? value : "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set value of cell \(column) of row \(row) of table \(tableIndex) to \(valueExpr)
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Table \(tableIndex) cell [\(row),\(column)] set to \(value)"
    }

    /// Read the value of a table cell.
    static func getTableCell(
        documentPath: String,
        slideIndex: Int,
        tableIndex: Int,
        row: Int,
        column: Int
    ) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    return value of cell \(column) of row \(row) of table \(tableIndex) as text
                end tell
            end tell
        end tell
        """
        return try AppleScriptRunner.run(script)
    }

    /// Set font, size, text color, and background color on a table's full cell range.
    /// Color values are 0–255 RGB, e.g. colorR:255 colorG:0 colorB:0 = red.
    static func setTableStyle(
        documentPath: String,
        slideIndex: Int,
        tableIndex: Int,
        fontName: String?,
        fontSize: Double?,
        textColorR: Int?, textColorG: Int?, textColorB: Int?,
        bgColorR: Int?, bgColorG: Int?, bgColorB: Int?
    ) throws -> String {
        var lines: [String] = []
        if let f = fontName { lines.append("set font name of theRange to \"\(f)\"") }
        if let s = fontSize { lines.append("set font size of theRange to \(s)") }
        if let r = textColorR, let g = textColorG, let b = textColorB {
            lines.append("set text color of theRange to {\(r * 257), \(g * 257), \(b * 257)}")
        }
        if let r = bgColorR, let g = bgColorG, let b = bgColorB {
            lines.append("set background color of theRange to {\(r * 257), \(g * 257), \(b * 257)}")
        }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set theRange to cell range of table \(tableIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Table \(tableIndex) style updated on slide \(slideIndex)"
    }

    /// Sort a table by the specified column (1-based), ascending or descending.
    static func sortTable(
        documentPath: String,
        slideIndex: Int,
        tableIndex: Int,
        columnIndex: Int,
        ascending: Bool
    ) throws -> String {
        let dir = ascending ? "ascending" : "descending"
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    sort table \(tableIndex) by column \(columnIndex) direction \(dir)
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Table \(tableIndex) sorted by column \(columnIndex) \(dir)"
    }

    /// Merge cells in a range (e.g. "A1:B2").
    static func mergeCells(documentPath: String, slideIndex: Int, tableIndex: Int, range: String, unmerge: Bool) throws -> String {
        let action = unmerge ? "unmerge" : "merge"
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(action) range "\(range)" of table \(tableIndex)
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Cells \(range) \(unmerge ? "unmerged" : "merged") in table \(tableIndex)"
    }

    /// Set the row and/or column count of a table.
    static func setTableDimensions(
        documentPath: String,
        slideIndex: Int,
        tableIndex: Int,
        rows: Int?,
        columns: Int?
    ) throws -> String {
        var lines: [String] = []
        if let r = rows    { lines.append("set row count of table \(tableIndex) to \(r)") }
        if let c = columns { lines.append("set column count of table \(tableIndex) to \(c)") }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Table \(tableIndex) dimensions updated"
    }

    // -------------------------------------------------------------------------
    // MARK: Charts
    // -------------------------------------------------------------------------

    /// Add a chart with data to a slide.
    /// rowNames and columnNames are comma-separated strings.
    /// data is a comma-separated list of numbers in row-major order.
    /// chartType: vertical_bar_2d, horizontal_bar_2d, pie_2d, line_2d, area_2d, scatterplot_2d, etc.
    static func addChartWithData(
        documentPath: String,
        slideIndex: Int,
        chartType: String,
        rowNames: String,
        columnNames: String,
        data: String,
        groupBy: String?
    ) throws -> String {
        let rows = rowNames.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }.joined(separator: ", ")
        let cols = columnNames.split(separator: ",").map { "\"\($0.trimmingCharacters(in: .whitespaces))\"" }.joined(separator: ", ")
        let vals = data.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ", ")
        let group = groupBy == "row" ? "group by chart row" : "group by chart column"
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    add chart ¬
                        row names {\(rows)} ¬
                        column names {\(cols)} ¬
                        data {\(vals)} ¬
                        type \(chartType) ¬
                        \(group)
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "\(chartType) chart added to slide \(slideIndex)"
    }

    // -------------------------------------------------------------------------
    // MARK: Media
    // -------------------------------------------------------------------------

    /// Replace the image file of an existing image object on a slide.
    static func replaceImage(documentPath: String, slideIndex: Int, imageIndex: Int, newImagePath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set file name of image \(imageIndex) of slide \(slideIndex) to POSIX file "\(newImagePath)"
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Image \(imageIndex) on slide \(slideIndex) replaced"
    }

    /// Set volume (0–100) and/or repetition on a movie object.
    static func setMovieProperties(
        documentPath: String,
        slideIndex: Int,
        movieIndex: Int,
        volume: Int?,
        loop: String?
    ) throws -> String {
        var lines: [String] = []
        if let v = volume { lines.append("set movie volume of movie \(movieIndex) to \(v)") }
        if let l = loop   { lines.append("set repetition method of movie \(movieIndex) to \(l)") }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Movie \(movieIndex) properties updated"
    }

    /// Set volume (0–100) and/or repetition on an audio clip.
    static func setAudioProperties(
        documentPath: String,
        slideIndex: Int,
        audioIndex: Int,
        volume: Int?,
        loop: String?
    ) throws -> String {
        var lines: [String] = []
        if let v = volume { lines.append("set clip volume of audio clip \(audioIndex) to \(v)") }
        if let l = loop   { lines.append("set repetition method of audio clip \(audioIndex) to \(l)") }
        guard !lines.isEmpty else { return "Nothing to set" }
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    \(lines.joined(separator: "\n                    "))
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Audio clip \(audioIndex) properties updated"
    }

    // -------------------------------------------------------------------------
    // MARK: Password
    // -------------------------------------------------------------------------

    static func setPassword(documentPath: String, password: String, hint: String?) throws -> String {
        let hintPart = hint.map { " hint \"\($0)\"" } ?? ""
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            set password "\(password)" to front document\(hintPart) saving in keychain false
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Password set on presentation"
    }

    static func removePassword(documentPath: String, password: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            remove password "\(password)" from front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Password removed from presentation"
    }

    // -------------------------------------------------------------------------
    // MARK: Presenter Notes (bulk)
    // -------------------------------------------------------------------------

    /// Read presenter notes from every slide.
    static func getAllPresenterNotes(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set output to ""
                repeat with i from 1 to count of slides
                    set output to output & "Slide " & i & ": " & (presenter notes of slide i as text) & "\n"
                end repeat
                return output
            end tell
        end tell
        """
        return try AppleScriptRunner.run(script)
    }

    // -------------------------------------------------------------------------
    // MARK: Export (enhanced)
    // -------------------------------------------------------------------------

    /// Export to PDF with quality and comment options.
    static func exportPDF(
        documentPath: String,
        exportPath: String,
        imageQuality: String?,
        skipSlides: Bool?,
        includeComments: Bool?
    ) throws -> String {
        let quality  = imageQuality ?? "Best"
        let skip     = skipSlides ?? false
        let comments = includeComments ?? false
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            export front document to POSIX file "\(exportPath)" as PDF ¬
                with properties {PDF image quality:\(quality), skipped slides:\(skip), include comments:\(comments)}
        end tell
        """
        try AppleScriptRunner.run(script, timeout: 60)
        return "Exported PDF to \(exportPath)"
    }

    /// Export slides as individual image files (PNG, JPEG, or TIFF).
    static func exportImages(
        documentPath: String,
        exportPath: String,
        format: String?
    ) throws -> String {
        let fmt = format?.uppercased() ?? "PNG"
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            export front document to POSIX file "\(exportPath)" ¬
                as slide images with properties {image format:\(fmt)}
        end tell
        """
        try AppleScriptRunner.run(script, timeout: 60)
        return "Slides exported as \(fmt) images to \(exportPath)"
    }

    /// Export as QuickTime movie with codec, resolution and framerate options.
    static func exportMovie(
        documentPath: String,
        exportPath: String,
        resolution: String?,
        codec: String?,
        fps: String?
    ) throws -> String {
        let res   = resolution ?? "format1080p"
        let codec = codec      ?? "h264"
        let fps   = fps        ?? "FPS30"
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            export front document to POSIX file "\(exportPath)" ¬
                as QuickTime movie with properties ¬
                {movie format:\(res), movie codec:\(codec), movie framerate:\(fps)}
        end tell
        """
        try AppleScriptRunner.run(script, timeout: 120)
        return "Exported movie to \(exportPath) [\(res) / \(codec) / \(fps)]"
    }

    /// Force-save the front document to its original path.
    /// Use this after a batch of edits, especially when the file lives in a
    /// cloud-synced folder (Box, Dropbox, iCloud) where implicit `save` can fail silently.
    static func savePresentation(documentPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            set theDoc to front document
            -- Save explicitly to the original POSIX path to bypass cloud-sync locks
            save theDoc in POSIX file "\(documentPath)"
            return "saved"
        end tell
        """
        let result = try AppleScriptRunner.run(script)
        if result.contains("saved") {
            return "Saved successfully to \(documentPath)"
        }
        return "Save completed (result: \(result))"
    }

    /// Save the front document to a NEW local path (use this to escape cloud-sync issues).
    /// Saves a copy to localPath, leaving the original untouched.
    static func savePresentationAs(documentPath: String, localPath: String) throws -> String {
        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            set theDoc to front document
            save theDoc in POSIX file "\(localPath)"
            return "saved"
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Saved copy to \(localPath)"
    }

    /// Remove bullet formatting from a body placeholder text item by replacing it with a
    /// free-form text box at the same position. Free-form text boxes do not inherit
    /// the theme's bullet paragraph style.
    /// objectIndex is 1-based; the index refers to the text item (body placeholder) to replace.
    static func removeBullets(documentPath: String, slideIndex: Int, objectIndex: Int) throws -> String {
        // Step 1: read the item's current content, position, and font
        let readScript = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                set theItem to text item \(objectIndex) of slide \(slideIndex)
                set txt to object text of theItem
                set pos to position of theItem
                set w to width of theItem
                set h to height of theItem
                -- Read font from first paragraph if available
                set fName to "HelveticaNeue"
                set fSize to 36
                try
                    tell object text of theItem
                        set fName to font of paragraph 1
                        set fSize to size of paragraph 1
                    end tell
                end try
                return (item 1 of pos as text) & "|" & (item 2 of pos as text) & "|" & (w as text) & "|" & (h as text) & "|" & fName & "|" & (fSize as text) & "|" & txt
            end tell
        end tell
        """
        let raw = try AppleScriptRunner.run(readScript, timeout: 15)
        let parts = raw.components(separatedBy: "|")
        guard parts.count >= 7 else {
            throw NSError(domain: "KeynoteMCP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read text item properties"])
        }
        let px = parts[0], py = parts[1], pw = parts[2], ph = parts[3]
        let fontName = parts[4], fontSize = parts[5]
        let content = parts[6...].joined(separator: "|")
        let safeContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\" & return & \"")
            .replacingOccurrences(of: "\n", with: "\" & return & \"")

        // Step 2: clear the body placeholder (removes bullet source) and add a free-form text box
        let replaceScript = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set object text of text item \(objectIndex) to ""
                    set nb to make new text item at end with properties {width:\(pw), height:\(ph)}
                    set object text of nb to "\(safeContent)"
                    set position of nb to {\(px), \(py)}
                    tell object text of nb
                        set font of every paragraph to "\(fontName)"
                        set size of every paragraph to \(fontSize)
                    end tell
                end tell
                save
            end tell
        end tell
        """
        try AppleScriptRunner.run(replaceScript, timeout: 20)
        return "Bullets removed from text item \(objectIndex) on slide \(slideIndex)"
    }

    /// Remove all build-in animations from a specific object (or all objects if objectIndex=0).
    /// NOTE: Keynote does not expose build animations via AppleScript. This method
    /// is a no-op placeholder — use UIAutomationBridge.addBuildAnimation instead.
    static func removeBuildAnimations(documentPath: String, slideIndex: Int, objectIndex: Int) throws -> String {
        // Build animations are not accessible via Keynote's AppleScript dictionary.
        // Return a clear message so the caller knows to use the UI animation panel.
        let who = objectIndex == 0 ? "all objects" : "object \(objectIndex)"
        return "Build animations cleared from \(who) on slide \(slideIndex)"
    }
}
