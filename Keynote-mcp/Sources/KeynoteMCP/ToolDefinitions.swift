import MCP

// MARK: - Tool Name Constants

enum ToolName {
    static let createPresentation    = "create_presentation"
    static let addSlide              = "add_slide"
    static let deleteSlide           = "delete_slide"
    static let duplicateSlide        = "duplicate_slide"
    static let setSlideContent       = "set_slide_content"
    static let setPresenterNotes     = "set_presenter_notes"
    static let setSlideTransition    = "set_slide_transition"
    static let skipSlide             = "skip_slide"
    static let addTextBox            = "add_text_box"
    static let addImage              = "add_image"
    static let addVideo              = "add_video"
    static let add3DObject           = "add_3d_object"
    static let setObjectPosition     = "set_object_position"
    static let setTheme              = "set_theme"
    static let listThemes            = "list_themes"
    static let setDocumentProperties = "set_document_properties"
    static let getPresentationInfo   = "get_presentation_info"
    static let listSlides            = "list_slides"
    static let getAllSlides           = "get_all_slides"
    static let getSlideContent       = "get_slide_content"
    static let openPresentation      = "open_presentation"
    static let startSlideshow        = "start_slideshow"
    static let stopSlideshow         = "stop_slideshow"
    static let showNextSlide         = "show_next_slide"
    static let showPreviousSlide     = "show_previous_slide"
    static let makeImageSlides       = "make_image_slides"
    // Text & object styling
    static let setTextStyle          = "set_text_style"
    static let setObjectOpacity      = "set_object_opacity"
    static let setObjectReflection   = "set_object_reflection"
    static let setAllTransitions     = "set_all_transitions"
    // Tables
    static let setTableCell          = "set_table_cell"
    static let getTableCell          = "get_table_cell"
    static let setTableStyle         = "set_table_style"
    static let sortTable             = "sort_table"
    static let mergeCells            = "merge_cells"
    static let setTableDimensions    = "set_table_dimensions"
    // Charts
    static let addChartWithData      = "add_chart_with_data"
    // Media
    static let replaceImage          = "replace_image"
    static let setMovieProperties    = "set_movie_properties"
    static let setAudioProperties    = "set_audio_properties"
    // Password
    static let setPassword           = "set_password"
    static let removePassword        = "remove_password"
    // Presenter notes (bulk)
    static let getAllPresenterNotes   = "get_all_presenter_notes"
    // Enhanced export
    static let exportPDF             = "export_pdf"
    static let exportImages          = "export_images"
    static let exportMovie           = "export_movie"
    // UI Automation tools
    static let insertShape           = "insert_shape"
    static let insertChart           = "insert_chart"
    static let insertLine            = "insert_line"
    static let insertWebVideo        = "insert_web_video"
    static let recordAudio           = "record_audio"
    static let arrangeObject         = "arrange_object"
    static let alignObjects          = "align_objects"
    static let distributeObjects     = "distribute_objects"
    static let groupObjects          = "group_objects"
    static let lockObject            = "lock_object"
    static let setView               = "set_view"
    static let togglePresenterNotes  = "toggle_presenter_notes"
    static let listMenuItems         = "list_menu_items"
    static let addComment            = "add_comment"
    static let toggleComments        = "toggle_comments"
    static let openAnimatePanel      = "open_animate_panel"
    static let removeBullets         = "remove_bullets"
    static let addBuildAnimation     = "add_build_animation"
    static let removeBuildAnimations = "remove_build_animations"
    static let exportPresentation    = "export_presentation"
    static let savePresentation      = "save_presentation"
    static let savePresentationAs    = "save_presentation_as"
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
            name: ToolName.deleteSlide,
            description: "Delete a slide from the presentation.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide to delete")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.duplicateSlide,
            description: "Duplicate a slide and insert the copy after it.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide to duplicate")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.setPresenterNotes,
            description: "Set or replace the presenter notes on a specific slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "notes": stringProp("Presenter notes text")
                ],
                required: ["document_path", "slide_index", "notes"]
            )
        ),

        Tool(
            name: ToolName.setSlideTransition,
            description: "Set the transition effect on a slide. Effects include: magic move, dissolve, push, wipe, reveal, cube, flip, shimmer, sparkle, swing, fall, confetti, mosaic, page flip, pivot, reflection, revolving door, scale, swap, swoosh, twirl, twist, blinds, droplet, iris, and more.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "effect": stringProp("Transition effect name (e.g. 'magic move', 'dissolve', 'push')"),
                    "duration": numberProp("Transition duration in seconds (e.g. 1.0)"),
                    "direction": stringProp("Transition direction if applicable (e.g. 'left to right', 'top to bottom')")
                ],
                required: ["document_path", "slide_index", "effect"]
            )
        ),

        Tool(
            name: ToolName.skipSlide,
            description: "Mark a slide as skipped (hidden during presentation) or unskip it.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "skip": stringProp("'true' to skip the slide, 'false' to unskip it")
                ],
                required: ["document_path", "slide_index", "skip"]
            )
        ),

        Tool(
            name: ToolName.setObjectPosition,
            description: "Move, resize, or rotate the Nth object on a slide. Use list_slides and get_slide_content to identify object indexes.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_index": intProp("1-based index of the object on the slide"),
                    "x": numberProp("New X position in points from the left edge"),
                    "y": numberProp("New Y position in points from the top edge"),
                    "width": numberProp("New width in points"),
                    "height": numberProp("New height in points"),
                    "rotation": numberProp("Rotation in degrees (0–360)")
                ],
                required: ["document_path", "slide_index", "object_index"]
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
            name: ToolName.listThemes,
            description: "List all Keynote themes installed on this Mac.",
            inputSchema: schema(properties: [:])
        ),

        Tool(
            name: ToolName.setDocumentProperties,
            description: "Set document-level properties: slide number visibility, auto-loop, auto-play, auto-restart, idle timeout, and canvas dimensions.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_numbers_showing": stringProp("Show slide numbers: 'true' or 'false'"),
                    "auto_loop": stringProp("Loop presentation: 'true' or 'false'"),
                    "auto_play": stringProp("Auto-play on open: 'true' or 'false'"),
                    "auto_restart": stringProp("Restart after idle: 'true' or 'false'"),
                    "max_idle_duration": intProp("Seconds before auto-restart"),
                    "width": intProp("Slide canvas width in points (e.g. 1920)"),
                    "height": intProp("Slide canvas height in points (e.g. 1080)")
                ],
                required: ["document_path"]
            )
        ),

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
            name: ToolName.showNextSlide,
            description: "Advance to the next slide during a running slideshow.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.showPreviousSlide,
            description: "Go back to the previous slide during a running slideshow.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.makeImageSlides,
            description: "Bulk-create slides from a list of image files. Each image becomes one slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "image_paths": stringProp("Comma-separated list of full POSIX paths to image files")
                ],
                required: ["document_path", "image_paths"]
            )
        ),

        // ── Text & Object Styling ──────────────────────────────────────────

        Tool(
            name: ToolName.setTextStyle,
            description: "Set font name, size, and/or color on the text inside a specific shape on a slide. Color values are 0–255 RGB.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based shape/text item index on the slide"),
                    "font_name": stringProp("PostScript or display font name (e.g. 'Helvetica-Bold', 'SF Pro Display')"),
                    "font_size": numberProp("Font size in points"),
                    "color_r": intProp("Red 0–255"),
                    "color_g": intProp("Green 0–255"),
                    "color_b": intProp("Blue 0–255")
                ],
                required: ["document_path", "slide_index", "object_index"]
            )
        ),

        Tool(
            name: ToolName.setObjectOpacity,
            description: "Set the opacity (0–100) of an object on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based object index on the slide"),
                    "opacity": intProp("Opacity 0 (transparent) to 100 (opaque)")
                ],
                required: ["document_path", "slide_index", "object_index", "opacity"]
            )
        ),

        Tool(
            name: ToolName.setObjectReflection,
            description: "Enable or disable a reflection effect on an object.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based object index"),
                    "showing": stringProp("'true' to enable reflection, 'false' to disable"),
                    "value": intProp("Reflection strength 0–100")
                ],
                required: ["document_path", "slide_index", "object_index", "showing"]
            )
        ),

        Tool(
            name: ToolName.setAllTransitions,
            description: "Apply the same transition effect to every slide in the presentation at once.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "effect": stringProp("Transition effect (e.g. 'dissolve', 'magic move', 'push', 'cube', 'flip')"),
                    "duration": numberProp("Duration in seconds (e.g. 0.75)"),
                    "auto_transition": stringProp("'true' to advance slides automatically, 'false' for manual")
                ],
                required: ["document_path", "effect"]
            )
        ),

        // ── Tables ─────────────────────────────────────────────────────────

        Tool(
            name: ToolName.setTableCell,
            description: "Set the value of a cell in a table on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index on the slide"),
                    "row": intProp("1-based row number"),
                    "column": intProp("1-based column number"),
                    "value": stringProp("Value to set (number or text)")
                ],
                required: ["document_path", "slide_index", "table_index", "row", "column", "value"]
            )
        ),

        Tool(
            name: ToolName.getTableCell,
            description: "Read the value of a specific table cell.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index"),
                    "row": intProp("1-based row number"),
                    "column": intProp("1-based column number")
                ],
                required: ["document_path", "slide_index", "table_index", "row", "column"]
            )
        ),

        Tool(
            name: ToolName.setTableStyle,
            description: "Set font, size, text color, and background color across an entire table. Colors are 0–255 RGB.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index"),
                    "font_name": stringProp("Font name (e.g. 'Helvetica')"),
                    "font_size": numberProp("Font size in points"),
                    "text_color_r": intProp("Text red 0–255"),
                    "text_color_g": intProp("Text green 0–255"),
                    "text_color_b": intProp("Text blue 0–255"),
                    "bg_color_r": intProp("Background red 0–255"),
                    "bg_color_g": intProp("Background green 0–255"),
                    "bg_color_b": intProp("Background blue 0–255")
                ],
                required: ["document_path", "slide_index", "table_index"]
            )
        ),

        Tool(
            name: ToolName.sortTable,
            description: "Sort a table by a specific column.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index"),
                    "column_index": intProp("1-based column to sort by"),
                    "ascending": stringProp("'true' for ascending, 'false' for descending")
                ],
                required: ["document_path", "slide_index", "table_index", "column_index"]
            )
        ),

        Tool(
            name: ToolName.mergeCells,
            description: "Merge or unmerge a range of table cells (e.g. 'A1:B2').",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index"),
                    "range": stringProp("Cell range in A1 notation (e.g. 'A1:B2')"),
                    "unmerge": stringProp("'true' to unmerge, 'false' (or omit) to merge")
                ],
                required: ["document_path", "slide_index", "table_index", "range"]
            )
        ),

        Tool(
            name: ToolName.setTableDimensions,
            description: "Set the number of rows and/or columns in a table.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "table_index": intProp("1-based table index"),
                    "rows": intProp("Number of rows"),
                    "columns": intProp("Number of columns")
                ],
                required: ["document_path", "slide_index", "table_index"]
            )
        ),

        // ── Charts ─────────────────────────────────────────────────────────

        Tool(
            name: ToolName.addChartWithData,
            description: "Add a chart with data to a slide. Chart types: vertical_bar_2d, horizontal_bar_2d, pie_2d, line_2d, area_2d, scatterplot_2d, and their _3d variants.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "chart_type": stringProp("Chart type (e.g. 'vertical_bar_2d', 'pie_2d', 'line_2d')"),
                    "row_names": stringProp("Comma-separated row labels (e.g. 'Q1,Q2,Q3,Q4')"),
                    "column_names": stringProp("Comma-separated column labels (e.g. 'Revenue,Expenses')"),
                    "data": stringProp("Comma-separated numbers in row-major order (e.g. '50000,30000,75000,40000')"),
                    "group_by": stringProp("'column' (default) or 'row'")
                ],
                required: ["document_path", "slide_index", "chart_type", "row_names", "column_names", "data"]
            )
        ),

        // ── Media ──────────────────────────────────────────────────────────

        Tool(
            name: ToolName.replaceImage,
            description: "Swap the image file of an existing image object on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "image_index": intProp("1-based image object index on the slide"),
                    "new_image_path": stringProp("Full POSIX path to the replacement image file")
                ],
                required: ["document_path", "slide_index", "image_index", "new_image_path"]
            )
        ),

        Tool(
            name: ToolName.setMovieProperties,
            description: "Set volume and/or loop mode on a movie/video object. Loop values: none, loop, loop back and forth.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "movie_index": intProp("1-based movie object index on the slide"),
                    "volume": intProp("Volume 0–100"),
                    "loop": stringProp("Repetition: 'none', 'loop', or 'loop back and forth'")
                ],
                required: ["document_path", "slide_index", "movie_index"]
            )
        ),

        Tool(
            name: ToolName.setAudioProperties,
            description: "Set volume and/or loop mode on an audio clip object. Loop values: none, loop, loop back and forth.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "audio_index": intProp("1-based audio clip index on the slide"),
                    "volume": intProp("Volume 0–100"),
                    "loop": stringProp("Repetition: 'none', 'loop', or 'loop back and forth'")
                ],
                required: ["document_path", "slide_index", "audio_index"]
            )
        ),

        // ── Password ───────────────────────────────────────────────────────

        Tool(
            name: ToolName.setPassword,
            description: "Set a password on a Keynote presentation.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "password": stringProp("Password to set"),
                    "hint": stringProp("Optional password hint")
                ],
                required: ["document_path", "password"]
            )
        ),

        Tool(
            name: ToolName.removePassword,
            description: "Remove the password from a Keynote presentation.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "password": stringProp("Current password to remove")
                ],
                required: ["document_path", "password"]
            )
        ),

        // ── Presenter Notes (bulk) ─────────────────────────────────────────

        Tool(
            name: ToolName.getAllPresenterNotes,
            description: "Read presenter notes from every slide in one call.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        // ── Enhanced Export ────────────────────────────────────────────────

        Tool(
            name: ToolName.exportPDF,
            description: "Export a presentation to PDF with quality and comment options.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "export_path": stringProp("Output path (e.g. ~/Desktop/deck.pdf)"),
                    "image_quality": stringProp("PDF image quality: 'Good', 'Better', 'Best' (default: Best)"),
                    "skip_slides": stringProp("'true' to include skipped slides, 'false' to omit (default: false)"),
                    "include_comments": stringProp("'true' to include comments (default: false)")
                ],
                required: ["document_path", "export_path"]
            )
        ),

        Tool(
            name: ToolName.exportImages,
            description: "Export each slide as an individual image file (PNG, JPEG, or TIFF).",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "export_path": stringProp("Output folder path (e.g. ~/Desktop/slides/)"),
                    "format": stringProp("Image format: 'PNG' (default), 'JPEG', or 'TIFF'")
                ],
                required: ["document_path", "export_path"]
            )
        ),

        Tool(
            name: ToolName.exportMovie,
            description: "Export a presentation as a QuickTime movie. Resolutions: format360p, format540p, format720p, format1080p, format4K, formatNative. Codecs: h264, hevcCodec, proRes422, proRes4444. FPS: FPS24, FPS25, FPS2997, FPS30, FPS60.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "export_path": stringProp("Output path (e.g. ~/Desktop/deck.m4v)"),
                    "resolution": stringProp("Resolution (default: format1080p)"),
                    "codec": stringProp("Video codec (default: h264)"),
                    "fps": stringProp("Frame rate (default: FPS30)")
                ],
                required: ["document_path", "export_path"]
            )
        ),

        // ── Comments & Animations (UI) ─────────────────────────────────────

        Tool(
            name: ToolName.addComment,
            description: "Add a review comment to a specific object on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based object index on the slide"),
                    "text": stringProp("Comment text")
                ],
                required: ["document_path", "slide_index", "object_index", "text"]
            )
        ),

        Tool(
            name: ToolName.toggleComments,
            description: "Show or hide all comments in the presentation.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.openAnimatePanel,
            description: "Open Keynote's Animate panel so you can add build-in/build-out animations to objects. Select the object in Keynote first, then click 'Add an Effect'.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.removeBullets,
            description: "Remove bullet point formatting from a text item on a slide. Pass objectIndex=0 to strip bullets from all text items on the slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based object index (text item). Pass 0 to target all text items on the slide")
                ],
                required: ["document_path", "slide_index", "object_index"]
            )
        ),

        Tool(
            name: ToolName.addBuildAnimation,
            description: "Add a build-in animation to an iWork object on a slide via UI automation (Keynote does not expose build animations in its AppleScript dictionary). Selects the item, switches to the Animate inspector tab, and clicks 'Add an Effect'. Use objectIndex as the 1-based iWork item index (not text item index).",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based iWork item index of the object to animate (use get_slide_content to find the index)"),
                    "effect": stringProp("Animation effect: appear (default), fade, move_in, wipe, shimmer, sparkle, pop"),
                    "build_style": stringProp("How to reveal text: paragraph (default, one line at a time) or all_at_once")
                ],
                required: ["document_path", "slide_index", "object_index"]
            )
        ),

        Tool(
            name: ToolName.removeBuildAnimations,
            description: "Remove all build-in animations from an object on a slide. Pass objectIndex=0 to clear all objects on the slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based slide index"),
                    "object_index": intProp("1-based object index. Pass 0 to clear all objects on the slide")
                ],
                required: ["document_path", "slide_index", "object_index"]
            )
        ),

        // ── UI Automation ──────────────────────────────────────────────────

        Tool(
            name: ToolName.insertShape,
            description: "Insert a named shape onto a slide via the Insert → Shape menu. Shape names: Rectangle, Rounded Rectangle, Oval, Triangle, Right Triangle, Pentagon, Hexagon, Octagon, Star, Diamond, Arrow, and more.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "shape_name": stringProp("Shape name exactly as it appears in the Insert → Shape menu (e.g. 'Rectangle', 'Oval', 'Star')")
                ],
                required: ["document_path", "slide_index", "shape_name"]
            )
        ),

        Tool(
            name: ToolName.insertChart,
            description: "Insert a chart onto a slide and open the chart editor.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.insertLine,
            description: "Insert a line onto a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.insertWebVideo,
            description: "Embed a web video (YouTube, Vimeo, etc.) onto a slide by URL.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide"),
                    "url": stringProp("Full URL of the video (e.g. https://www.youtube.com/watch?v=...)")
                ],
                required: ["document_path", "slide_index", "url"]
            )
        ),

        Tool(
            name: ToolName.recordAudio,
            description: "Open Keynote's Record Audio dialog for a specific slide. The user must press Record and Stop inside Keynote.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the target slide")
                ],
                required: ["document_path", "slide_index"]
            )
        ),

        Tool(
            name: ToolName.arrangeObject,
            description: "Change the z-order (layering) of an object on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_index": intProp("1-based index of the object on the slide"),
                    "action": stringProp("One of: bring_to_front, bring_forward, send_to_back, send_backward")
                ],
                required: ["document_path", "slide_index", "object_index", "action"]
            )
        ),

        Tool(
            name: ToolName.alignObjects,
            description: "Align two or more objects on a slide relative to each other.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_indexes": stringProp("Comma-separated 1-based object indexes (e.g. '1,2,3')"),
                    "alignment": stringProp("One of: left, center, right, top, middle, bottom")
                ],
                required: ["document_path", "slide_index", "object_indexes", "alignment"]
            )
        ),

        Tool(
            name: ToolName.distributeObjects,
            description: "Distribute objects evenly across a slide horizontally or vertically.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_indexes": stringProp("Comma-separated 1-based object indexes (e.g. '1,2,3')"),
                    "direction": stringProp("One of: horizontal, vertical")
                ],
                required: ["document_path", "slide_index", "object_indexes", "direction"]
            )
        ),

        Tool(
            name: ToolName.groupObjects,
            description: "Group or ungroup selected objects on a slide.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_indexes": stringProp("Comma-separated 1-based object indexes to group/ungroup"),
                    "ungroup": stringProp("'true' to ungroup, 'false' (or omit) to group")
                ],
                required: ["document_path", "slide_index", "object_indexes"]
            )
        ),

        Tool(
            name: ToolName.lockObject,
            description: "Lock or unlock an object on a slide so it can't be accidentally moved.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "slide_index": intProp("1-based index of the slide"),
                    "object_index": intProp("1-based index of the object"),
                    "lock": stringProp("'true' to lock, 'false' to unlock")
                ],
                required: ["document_path", "slide_index", "object_index", "lock"]
            )
        ),

        Tool(
            name: ToolName.setView,
            description: "Switch the Keynote editing view.",
            inputSchema: schema(
                properties: [
                    "document_path": stringProp("Full POSIX path to the .key file"),
                    "view": stringProp("One of: navigator, light_table, outline, slide_only")
                ],
                required: ["document_path", "view"]
            )
        ),

        Tool(
            name: ToolName.togglePresenterNotes,
            description: "Show or hide the presenter notes panel in Keynote.",
            inputSchema: schema(
                properties: ["document_path": stringProp("Full POSIX path to the .key file")],
                required: ["document_path"]
            )
        ),

        Tool(
            name: ToolName.listMenuItems,
            description: "List all menu items in a Keynote menu bar menu. Use this to discover exact menu item names before scripting. Menus: File, Edit, Insert, Format, Arrange, View, Play, Slide, Window.",
            inputSchema: schema(
                properties: [
                    "menu_name": stringProp("Menu bar name to inspect (e.g. 'Insert', 'Arrange', 'Format')")
                ],
                required: ["menu_name"]
            )
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
