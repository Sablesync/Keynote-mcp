import MCP

// MARK: - Tool Name Constants

enum ToolName {
    static let createPresentation = "create_presentation"
    static let addSlide = "add_slide"
    static let setSlideContent = "set_slide_content"
    static let addTextBox = "add_text_box"
    static let addImage = "add_image"
    static let addVideo = "add_video"
    static let add3DObject = "add_3d_object"
    static let setTheme = "set_theme"
    static let getPresentationInfo = "get_presentation_info"
    static let listSlides = "list_slides"
    static let getAllSlides = "get_all_slides"
    static let getSlideContent = "get_slide_content"
    static let openPresentation = "open_presentation"
    static let startSlideshow = "start_slideshow"
    static let stopSlideshow = "stop_slideshow"
    static let exportPresentation = "export_presentation"
    static let savePresentation = "save_presentation"
    static let savePresentationAs = "save_presentation_as"
}

// MARK: - Schema Helpers
//
// The swift-sdk Value API represents JSON Schema as nested Value objects.
// .object(["key": value]) maps to a JSON object.
// .string("text") is a Value containing a string (used for description fields).
// Numeric types are encoded as JSON Schema "type" strings inside the schema object.

private func stringProp(_ description: String) -> Value {
    .object(["type": .string("string"), "description": .string(description)])
}

private func intProp(_ description: String) -> Value {
    .object(["type": .string("integer"), "description": .string(description)])
}

private func numberProp(_ description: String) -> Value {
    .object(["type": .string("number"), "description": .string(description)])
}

private func schema(
    properties: [String: Value],
    required: [String] = []
) -> Value {
    var obj: [String: Value] = [
        "type": .string("object"),
        "properties": .object(properties)
    ]
    if !required.isEmpty {
        obj["required"] = .array(required.map { .string($0) })
    }
    return .object(obj)
}

// MARK: - Tool Definitions

enum ToolDefinitions {
    static let all: [Tool] = [

        // ── Create & Edit ──────────────────────────────────────────────────

        Tool(
            name: ToolName.createPresentation,
            description: "Create a new Keynote presentation and save it to disk.",
            inputSchema: schema(
                properties: [
                    "title": stringProp("Title of the new presentation"),
                    "theme": stringProp("Optional Keynote theme name (e.g. 'White', 'Black', 'Gradient')"),
                    "output_path": stringProp("Full POSIX path where the .key file should be saved (e.g. /Users/you/Desktop/talk.key)")
                ],
                required: ["title", "output_path"]
            )
        ),

        Tool(
            name: ToolName.addSlide,
            description: "Add a new slide to an existing Keynote presentation.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "position": intProp("1-based slide index to insert at. Appends at end if omitted."),
                    "layout": stringProp("Slide layout name (e.g. 'Title & Content', 'Blank')")
                ],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.setSlideContent,
            description: "Set the title and/or body text on a specific slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "title": stringProp("Title text to set on the slide"),
                    "body": stringProp("Body text to set on the slide")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.addTextBox,
            description: "Add a free-floating text box to a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "text": stringProp("Text content for the text box"),
                    "x": numberProp("X position in points from the left edge"),
                    "y": numberProp("Y position in points from the top edge"),
                    "width": numberProp("Width of the text box in points"),
                    "height": numberProp("Height of the text box in points")
                ],
                required: ["document_path", "slide_index", "text"]
            )
        ),

        Tool(
            name: ToolName.addImage,
            description: "Add an image file to a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "image_path": stringProp("Full POSIX path to the image file (PNG, JPEG, etc.)"),
                    "x": numberProp("X position in points from the left edge"),
                    "y": numberProp("Y position in points from the top edge"),
                    "width": numberProp("Width in points"),
                    "height": numberProp("Height in points")
                ],
                required: ["document_path", "slide_index", "image_path"]
            )
        ),

        Tool(
            name: ToolName.addVideo,
            description: "Add a video file (MOV, MP4) to a slide with optional position, size, and playback settings. Supports autoplay and loop. NOTE: USDZ/3D objects cannot be added via AppleScript — use add_3d_object for those.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "video_path": stringProp("Full POSIX path to the video file (MOV, MP4)"),
                    "x": numberProp("X position in points from the left edge (default: 160)"),
                    "y": numberProp("Y position in points from the top edge (default: 90)"),
                    "width": numberProp("Width in points (default: 960)"),
                    "height": numberProp("Height in points (default: 540)"),
                    "autoplay": stringProp("Whether to autoplay when slide is shown: 'true' or 'false' (default: false)"),
                    "loop": stringProp("Whether to loop the video: 'true' or 'false' (default: false)")
                ],
                required: ["document_path", "slide_index", "video_path"]
            )
        ),

        Tool(
            name: ToolName.add3DObject,
            description: "Insert a 3D object (USDZ, USDA, USDC) onto a Keynote slide by automating the Insert > 3D Object menu using the macOS Accessibility API. Requires Accessibility permission granted to your terminal app in System Settings → Privacy & Security → Accessibility. Keynote must be visible on screen (not minimized).",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "object_path": stringProp("Full POSIX path to the 3D object file (USDZ, USDA, or USDC)")
                ],
                required: ["document_path", "slide_index", "object_path"]
            )
        ),

        Tool(
            name: ToolName.setTheme,
            description: "Change the theme of an existing Keynote presentation.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "theme_name": stringProp("Keynote theme name (e.g. 'White', 'Black', 'Gradient', 'Parchment')")
                ],
                required: ["document_path", "theme_name"]
            )
        ),

        // ── Read ───────────────────────────────────────────────────────────

        Tool(
            name: ToolName.getPresentationInfo,
            description: "Get high-level info about a Keynote presentation: name, slide count, and theme.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.listSlides,
            description: "List all slides in a presentation with their index and title.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.getAllSlides,
            description: "Get ALL slide content (title, body, notes) in a single call. Always prefer this over calling get_slide_content repeatedly — it is dramatically faster.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.getSlideContent,
            description: "Get the full text content (title, body, presenter notes) of a specific slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide to read")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        // ── Run & Export ───────────────────────────────────────────────────

        Tool(
            name: ToolName.openPresentation,
            description: "Open a Keynote file in Keynote and bring it to the front.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.startSlideshow,
            description: "Start the slideshow for the front Keynote document.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.stopSlideshow,
            description: "Stop the currently running Keynote slideshow.",
            inputSchema: schema(properties: [:])
        ),

        Tool(
            name: ToolName.exportPresentation,
            description: "Export a Keynote presentation to PDF, PowerPoint, HTML, or QuickTime Movie.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "export_path": stringProp("Full POSIX output path (e.g. /Users/you/Desktop/talk.pdf)"),
                    "format": stringProp("Export format: 'PDF', 'Microsoft PowerPoint', 'HTML', 'QuickTime Movie'")
                ],
                required: ["document_path", "export_path", "format"]
            )
        ),

        Tool(
            name: ToolName.savePresentation,
            description: "Force-save the presentation to disk. ALWAYS call this after a batch of edits. Critical when the file is in Box, Dropbox, or iCloud — implicit saves in those locations often fail silently.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file")
                ],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.savePresentationAs,
            description: "Save a copy of the presentation to a new local path. Use this to escape cloud-sync issues — save to ~/Desktop first, edit there, then move back.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the source .key file"),
                    "local_path": stringProp("Full POSIX path for the new copy (e.g. /Users/you/Desktop/working.key)")
                ],
                required: ["document_path", "local_path"]
            )
        )
    ]
}
