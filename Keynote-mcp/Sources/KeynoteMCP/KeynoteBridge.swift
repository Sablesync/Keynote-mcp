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
    /// Runs an AppleScript and returns the string result.
    /// Throws `AppleScriptError` on failure so callers can surface it as an MCP error.
    @discardableResult
    static func run(_ script: String) throws -> String {
        var errorDict: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        guard let descriptor = appleScript?.executeAndReturnError(&errorDict) else {
            let message = (errorDict?[NSAppleScript.errorMessage] as? String)
                ?? (errorDict?.description)
                ?? "Unknown AppleScript error"
            throw AppleScriptError.executionFailed(message)
        }
        return descriptor.stringValue ?? ""
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
    static func addTextBox(
        documentPath: String,
        slideIndex: Int,
        text: String,
        x: Double?, y: Double?,
        width: Double?, height: Double?
    ) throws -> String {
        let posProps: String
        if let x = x, let y = y, let w = width, let h = height {
            posProps = "{position:{x:\(Int(x)), y:\(Int(y))}, width:\(Int(w)), height:\(Int(h))}"
        } else {
            posProps = "{position:{x:100, y:100}, width:400, height:100}"
        }

        let script = """
        tell application "Keynote"
            open POSIX file "\(documentPath)"
            tell front document
                tell slide \(slideIndex)
                    set tb to make new text item with properties \(posProps)
                    set object text of tb to "\(text)"
                end tell
            end tell
            save front document
        end tell
        """
        try AppleScriptRunner.run(script)
        return "Text box added to slide \(slideIndex)"
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
}
