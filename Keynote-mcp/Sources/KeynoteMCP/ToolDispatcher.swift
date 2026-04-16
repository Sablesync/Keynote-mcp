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

        case ToolName.setTheme:
            let docPath = try requireString(args, key: "document_path")
            let themeName = try requireString(args, key: "theme_name")
            return try KeynoteBridge.setTheme(documentPath: docPath, themeName: themeName)

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
