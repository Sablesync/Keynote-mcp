import MCP
import Foundation

// MARK: - Tool Dispatcher

/// Routes incoming MCP `tools/call` requests to the appropriate KeynoteBridge function.
/// All errors from KeynoteBridge are rethrown and will surface as MCP error responses.
enum ToolDispatcher {

    static func dispatch(name: String, arguments: [String: Value]?) throws -> String {
        let args = arguments ?? [:]

        switch name {

        // ── Create & Edit ─────────────────────────────────────────────────

        case ToolName.createPresentation:
            let title = try requireString(args, key: "title")
            let outputPath = try requireString(args, key: "output_path")
            let theme = optionalString(args, key: "theme")
            return try KeynoteBridge.createPresentation(
                title: title, theme: theme, outputPath: outputPath
            )

        case ToolName.addSlide:
            let docPath = try requireString(args, key: "document_path")
            let position = optionalInt(args, key: "position")
            let layout = optionalString(args, key: "layout")
            return try KeynoteBridge.addSlide(
                documentPath: docPath, position: position, layout: layout
            )

        case ToolName.setSlideContent:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let title = optionalString(args, key: "title")
            let body = optionalString(args, key: "body")
            return try KeynoteBridge.setSlideContent(
                documentPath: docPath, slideIndex: slideIndex, title: title, body: body
            )

        case ToolName.addTextBox:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let text = try requireString(args, key: "text")
            let x = optionalDouble(args, key: "x")
            let y = optionalDouble(args, key: "y")
            let width = optionalDouble(args, key: "width")
            let height = optionalDouble(args, key: "height")
            return try KeynoteBridge.addTextBox(
                documentPath: docPath, slideIndex: slideIndex, text: text,
                x: x, y: y, width: width, height: height
            )

        case ToolName.addImage:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let imagePath = try requireString(args, key: "image_path")
            let x = optionalDouble(args, key: "x")
            let y = optionalDouble(args, key: "y")
            let width = optionalDouble(args, key: "width")
            let height = optionalDouble(args, key: "height")
            return try KeynoteBridge.addImage(
                documentPath: docPath, slideIndex: slideIndex, imagePath: imagePath,
                x: x, y: y, width: width, height: height
            )

        case ToolName.addVideo:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let videoPath = try requireString(args, key: "video_path")
            let x = optionalDouble(args, key: "x")
            let y = optionalDouble(args, key: "y")
            let width = optionalDouble(args, key: "width")
            let height = optionalDouble(args, key: "height")
            let autoplay = optionalString(args, key: "autoplay") == "true"
            let loop = optionalString(args, key: "loop") == "true"
            return try KeynoteBridge.addVideo(
                documentPath: docPath, slideIndex: slideIndex, videoPath: videoPath,
                x: x, y: y, width: width, height: height,
                autoplay: autoplay, loop: loop
            )

        case ToolName.add3DObject:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectPath = try requireString(args, key: "object_path")
            return try AccessibilityBridge.add3DObject(
                documentPath: docPath,
                slideIndex: slideIndex,
                objectPath: objectPath
            )

        case ToolName.deleteSlide:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try KeynoteBridge.deleteSlide(documentPath: docPath, slideIndex: slideIndex)

        case ToolName.duplicateSlide:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try KeynoteBridge.duplicateSlide(documentPath: docPath, slideIndex: slideIndex)

        case ToolName.setPresenterNotes:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let notes = try requireString(args, key: "notes")
            return try KeynoteBridge.setPresenterNotes(documentPath: docPath, slideIndex: slideIndex, notes: notes)

        case ToolName.setSlideTransition:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let effect = try requireString(args, key: "effect")
            let duration = optionalDouble(args, key: "duration")
            let direction = optionalString(args, key: "direction")
            return try KeynoteBridge.setSlideTransition(
                documentPath: docPath, slideIndex: slideIndex,
                effect: effect, duration: duration, direction: direction
            )

        case ToolName.skipSlide:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let skip = optionalString(args, key: "skip") == "true"
            return try KeynoteBridge.skipSlide(documentPath: docPath, slideIndex: slideIndex, skip: skip)

        case ToolName.setObjectPosition:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let x = optionalDouble(args, key: "x")
            let y = optionalDouble(args, key: "y")
            let width = optionalDouble(args, key: "width")
            let height = optionalDouble(args, key: "height")
            let rotation = optionalDouble(args, key: "rotation")
            return try KeynoteBridge.setObjectPosition(
                documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex,
                x: x, y: y, width: width, height: height, rotation: rotation
            )

        case ToolName.setTheme:
            let docPath = try requireString(args, key: "document_path")
            let themeName = try requireString(args, key: "theme_name")
            return try KeynoteBridge.setTheme(documentPath: docPath, themeName: themeName)

        case ToolName.listThemes:
            return try KeynoteBridge.listThemes()

        case ToolName.setDocumentProperties:
            let docPath = try requireString(args, key: "document_path")
            let slideNumbers = optionalString(args, key: "slide_numbers_showing").map { $0 == "true" }
            let autoLoop     = optionalString(args, key: "auto_loop").map { $0 == "true" }
            let autoPlay     = optionalString(args, key: "auto_play").map { $0 == "true" }
            let autoRestart  = optionalString(args, key: "auto_restart").map { $0 == "true" }
            let maxIdle      = optionalInt(args, key: "max_idle_duration")
            let width        = optionalInt(args, key: "width")
            let height       = optionalInt(args, key: "height")
            return try KeynoteBridge.setDocumentProperties(
                documentPath: docPath,
                slideNumbersShowing: slideNumbers, autoLoop: autoLoop,
                autoPlay: autoPlay, autoRestart: autoRestart,
                maxIdleDuration: maxIdle, width: width, height: height
            )

        // ── Read ──────────────────────────────────────────────────────────

        case ToolName.getPresentationInfo:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.getPresentationInfo(documentPath: docPath)

        case ToolName.listSlides:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.listSlides(documentPath: docPath)

        case ToolName.getAllSlides:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.getAllSlides(documentPath: docPath)

        case ToolName.getSlideContent:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try KeynoteBridge.getSlideContent(documentPath: docPath, slideIndex: slideIndex)

        // ── Run & Export ──────────────────────────────────────────────────

        case ToolName.openPresentation:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.openPresentation(documentPath: docPath)

        case ToolName.startSlideshow:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.startSlideshow(documentPath: docPath)

        case ToolName.stopSlideshow:
            return try KeynoteBridge.stopSlideshow()

        case ToolName.showNextSlide:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.showNextSlide(documentPath: docPath)

        case ToolName.showPreviousSlide:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.showPreviousSlide(documentPath: docPath)

        case ToolName.makeImageSlides:
            let docPath = try requireString(args, key: "document_path")
            let raw = try requireString(args, key: "image_paths")
            let paths = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return try KeynoteBridge.makeImageSlides(documentPath: docPath, imagePaths: paths)

        // ── UI Automation ─────────────────────────────────────────────────

        case ToolName.insertShape:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let shapeName = try requireString(args, key: "shape_name")
            return try UIAutomationBridge.insertShape(documentPath: docPath, slideIndex: slideIndex, shapeName: shapeName)

        case ToolName.insertChart:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try UIAutomationBridge.insertChart(documentPath: docPath, slideIndex: slideIndex)

        case ToolName.insertLine:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try UIAutomationBridge.insertLine(documentPath: docPath, slideIndex: slideIndex)

        case ToolName.insertWebVideo:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let url = try requireString(args, key: "url")
            return try UIAutomationBridge.insertWebVideo(documentPath: docPath, slideIndex: slideIndex, url: url)

        case ToolName.recordAudio:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            return try UIAutomationBridge.recordAudio(documentPath: docPath, slideIndex: slideIndex)

        case ToolName.arrangeObject:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let action = try requireString(args, key: "action")
            return try UIAutomationBridge.arrangeObject(documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex, action: action)

        case ToolName.alignObjects:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let raw = try requireString(args, key: "object_indexes")
            let indexes = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let alignment = try requireString(args, key: "alignment")
            return try UIAutomationBridge.alignObjects(documentPath: docPath, slideIndex: slideIndex, objectIndexes: indexes, alignment: alignment)

        case ToolName.distributeObjects:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let raw = try requireString(args, key: "object_indexes")
            let indexes = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let direction = try requireString(args, key: "direction")
            return try UIAutomationBridge.distributeObjects(documentPath: docPath, slideIndex: slideIndex, objectIndexes: indexes, direction: direction)

        case ToolName.groupObjects:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let raw = try requireString(args, key: "object_indexes")
            let indexes = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let ungroup = optionalString(args, key: "ungroup") == "true"
            return try UIAutomationBridge.groupObjects(documentPath: docPath, slideIndex: slideIndex, objectIndexes: indexes, ungroup: ungroup)

        case ToolName.lockObject:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let lock = optionalString(args, key: "lock") == "true"
            return try UIAutomationBridge.lockObject(documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex, lock: lock)

        case ToolName.setView:
            let docPath = try requireString(args, key: "document_path")
            let view = try requireString(args, key: "view")
            return try UIAutomationBridge.setView(documentPath: docPath, view: view)

        case ToolName.togglePresenterNotes:
            let docPath = try requireString(args, key: "document_path")
            return try UIAutomationBridge.togglePresenterNotes(documentPath: docPath)

        case ToolName.listMenuItems:
            let menuName = try requireString(args, key: "menu_name")
            return try UIAutomationBridge.listMenuItems(menuName: menuName)

        case ToolName.exportPresentation:
            let docPath = try requireString(args, key: "document_path")
            let exportPath = try requireString(args, key: "export_path")
            let format = try requireString(args, key: "format")
            return try KeynoteBridge.exportPresentation(
                documentPath: docPath, exportPath: exportPath, format: format
            )

        case ToolName.savePresentation:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.savePresentation(documentPath: docPath)

        case ToolName.savePresentationAs:
            let docPath = try requireString(args, key: "document_path")
            let localPath = try requireString(args, key: "local_path")
            return try KeynoteBridge.savePresentationAs(documentPath: docPath, localPath: localPath)

        default:
            throw DispatchError.unknownTool(name)
        }
    }

    // ── Argument Helpers ──────────────────────────────────────────────────

    private static func requireString(_ args: [String: Value], key: String) throws -> String {
        guard case .string(let v) = args[key] else {
            throw DispatchError.missingArgument(key)
        }
        return v
    }

    private static func requireInt(_ args: [String: Value], key: String) throws -> Int {
        switch args[key] {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: throw DispatchError.missingArgument(key)
        }
    }

    private static func optionalString(_ args: [String: Value], key: String) -> String? {
        guard case .string(let v) = args[key] else { return nil }
        return v
    }

    private static func optionalInt(_ args: [String: Value], key: String) -> Int? {
        switch args[key] {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return nil
        }
    }

    private static func optionalDouble(_ args: [String: Value], key: String) -> Double? {
        switch args[key] {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return nil
        }
    }
}

// MARK: - Dispatch Error

enum DispatchError: Error, LocalizedError {
    case unknownTool(String)
    case missingArgument(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name): return "Unknown tool: \(name)"
        case .missingArgument(let key): return "Missing required argument: \(key)"
        }
    }
}
