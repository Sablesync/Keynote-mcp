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

        // ── Text & Object Styling ─────────────────────────────────────────

        case ToolName.setTextStyle:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let fontName = optionalString(args, key: "font_name")
            let fontSize = optionalDouble(args, key: "font_size")
            let colorR = optionalInt(args, key: "color_r")
            let colorG = optionalInt(args, key: "color_g")
            let colorB = optionalInt(args, key: "color_b")
            return try KeynoteBridge.setTextStyle(
                documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex,
                fontName: fontName, fontSize: fontSize,
                colorR: colorR, colorG: colorG, colorB: colorB
            )

        case ToolName.setObjectOpacity:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let opacity = try requireInt(args, key: "opacity")
            return try KeynoteBridge.setObjectOpacity(
                documentPath: docPath, slideIndex: slideIndex,
                objectIndex: objectIndex, opacity: opacity
            )

        case ToolName.setObjectReflection:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let showing = optionalString(args, key: "showing") == "true"
            let value = optionalInt(args, key: "value")
            return try KeynoteBridge.setObjectReflection(
                documentPath: docPath, slideIndex: slideIndex,
                objectIndex: objectIndex, showing: showing, value: value
            )

        case ToolName.setAllTransitions:
            let docPath = try requireString(args, key: "document_path")
            let effect = try requireString(args, key: "effect")
            let duration = optionalDouble(args, key: "duration")
            let autoTransition = optionalString(args, key: "auto_transition").map { $0 == "true" }
            return try KeynoteBridge.setAllTransitions(
                documentPath: docPath, effect: effect,
                duration: duration, autoTransition: autoTransition
            )

        // ── Tables ────────────────────────────────────────────────────────

        case ToolName.setTableCell:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let row = try requireInt(args, key: "row")
            let column = try requireInt(args, key: "column")
            let value = try requireString(args, key: "value")
            return try KeynoteBridge.setTableCell(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                row: row, column: column, value: value
            )

        case ToolName.getTableCell:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let row = try requireInt(args, key: "row")
            let column = try requireInt(args, key: "column")
            return try KeynoteBridge.getTableCell(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                row: row, column: column
            )

        case ToolName.setTableStyle:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let fontName = optionalString(args, key: "font_name")
            let fontSize = optionalDouble(args, key: "font_size")
            let textColorR = optionalInt(args, key: "text_color_r")
            let textColorG = optionalInt(args, key: "text_color_g")
            let textColorB = optionalInt(args, key: "text_color_b")
            let bgColorR = optionalInt(args, key: "bg_color_r")
            let bgColorG = optionalInt(args, key: "bg_color_g")
            let bgColorB = optionalInt(args, key: "bg_color_b")
            return try KeynoteBridge.setTableStyle(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                fontName: fontName, fontSize: fontSize,
                textColorR: textColorR, textColorG: textColorG, textColorB: textColorB,
                bgColorR: bgColorR, bgColorG: bgColorG, bgColorB: bgColorB
            )

        case ToolName.sortTable:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let columnIndex = try requireInt(args, key: "column_index")
            let ascending = optionalString(args, key: "ascending") != "false"
            return try KeynoteBridge.sortTable(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                columnIndex: columnIndex, ascending: ascending
            )

        case ToolName.mergeCells:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let range = try requireString(args, key: "range")
            let unmerge = optionalString(args, key: "unmerge") == "true"
            return try KeynoteBridge.mergeCells(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                range: range, unmerge: unmerge
            )

        case ToolName.setTableDimensions:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let tableIndex = try requireInt(args, key: "table_index")
            let rows = optionalInt(args, key: "rows")
            let columns = optionalInt(args, key: "columns")
            return try KeynoteBridge.setTableDimensions(
                documentPath: docPath, slideIndex: slideIndex, tableIndex: tableIndex,
                rows: rows, columns: columns
            )

        // ── Charts ────────────────────────────────────────────────────────

        case ToolName.addChartWithData:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let chartType = try requireString(args, key: "chart_type")
            let rowNames = try requireString(args, key: "row_names")
            let columnNames = try requireString(args, key: "column_names")
            let data = try requireString(args, key: "data")
            let groupBy = optionalString(args, key: "group_by")
            return try KeynoteBridge.addChartWithData(
                documentPath: docPath, slideIndex: slideIndex, chartType: chartType,
                rowNames: rowNames, columnNames: columnNames, data: data, groupBy: groupBy
            )

        // ── Media ─────────────────────────────────────────────────────────

        case ToolName.replaceImage:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let imageIndex = try requireInt(args, key: "image_index")
            let newImagePath = try requireString(args, key: "new_image_path")
            return try KeynoteBridge.replaceImage(
                documentPath: docPath, slideIndex: slideIndex,
                imageIndex: imageIndex, newImagePath: newImagePath
            )

        case ToolName.setMovieProperties:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let movieIndex = try requireInt(args, key: "movie_index")
            let volume = optionalInt(args, key: "volume")
            let loop = optionalString(args, key: "loop")
            return try KeynoteBridge.setMovieProperties(
                documentPath: docPath, slideIndex: slideIndex,
                movieIndex: movieIndex, volume: volume, loop: loop
            )

        case ToolName.setAudioProperties:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let audioIndex = try requireInt(args, key: "audio_index")
            let volume = optionalInt(args, key: "volume")
            let loop = optionalString(args, key: "loop")
            return try KeynoteBridge.setAudioProperties(
                documentPath: docPath, slideIndex: slideIndex,
                audioIndex: audioIndex, volume: volume, loop: loop
            )

        // ── Password & Notes ──────────────────────────────────────────────

        case ToolName.setPassword:
            let docPath = try requireString(args, key: "document_path")
            let password = try requireString(args, key: "password")
            let hint = optionalString(args, key: "hint")
            return try KeynoteBridge.setPassword(
                documentPath: docPath, password: password, hint: hint
            )

        case ToolName.removePassword:
            let docPath = try requireString(args, key: "document_path")
            let password = try requireString(args, key: "password")
            return try KeynoteBridge.removePassword(documentPath: docPath, password: password)

        case ToolName.getAllPresenterNotes:
            let docPath = try requireString(args, key: "document_path")
            return try KeynoteBridge.getAllPresenterNotes(documentPath: docPath)

        // ── Enhanced Export ───────────────────────────────────────────────

        case ToolName.exportPDF:
            let docPath = try requireString(args, key: "document_path")
            let exportPath = try requireString(args, key: "export_path")
            let imageQuality = optionalString(args, key: "image_quality")
            let skipSlides = optionalString(args, key: "skip_slides").map { $0 == "true" }
            let includeComments = optionalString(args, key: "include_comments").map { $0 == "true" }
            return try KeynoteBridge.exportPDF(
                documentPath: docPath, exportPath: exportPath,
                imageQuality: imageQuality, skipSlides: skipSlides, includeComments: includeComments
            )

        case ToolName.exportImages:
            let docPath = try requireString(args, key: "document_path")
            let exportPath = try requireString(args, key: "export_path")
            let format = optionalString(args, key: "format")
            return try KeynoteBridge.exportImages(
                documentPath: docPath, exportPath: exportPath, format: format
            )

        case ToolName.exportMovie:
            let docPath = try requireString(args, key: "document_path")
            let exportPath = try requireString(args, key: "export_path")
            let resolution = optionalString(args, key: "resolution")
            let codec = optionalString(args, key: "codec")
            let fps = optionalString(args, key: "fps")
            return try KeynoteBridge.exportMovie(
                documentPath: docPath, exportPath: exportPath,
                resolution: resolution, codec: codec, fps: fps
            )

        // ── UI Automation: Comments & Animate ─────────────────────────────

        case ToolName.removeBullets:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            return try KeynoteBridge.removeBullets(
                documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex
            )

        case ToolName.addBuildAnimation:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let effect = optionalString(args, key: "effect") ?? "appear"
            let buildBy = optionalString(args, key: "build_style")
            return try UIAutomationBridge.addBuildAnimation(
                documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex,
                effect: effect, buildBy: buildBy
            )

        case ToolName.removeBuildAnimations:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            return try KeynoteBridge.removeBuildAnimations(
                documentPath: docPath, slideIndex: slideIndex, objectIndex: objectIndex
            )

        case ToolName.addComment:
            let docPath = try requireString(args, key: "document_path")
            let slideIndex = try requireInt(args, key: "slide_index")
            let objectIndex = try requireInt(args, key: "object_index")
            let text = try requireString(args, key: "text")
            return try UIAutomationBridge.addComment(
                documentPath: docPath, slideIndex: slideIndex,
                objectIndex: objectIndex, text: text
            )

        case ToolName.toggleComments:
            let docPath = try requireString(args, key: "document_path")
            return try UIAutomationBridge.toggleComments(documentPath: docPath)

        case ToolName.openAnimatePanel:
            let docPath = try requireString(args, key: "document_path")
            return try UIAutomationBridge.openAnimatePanel(documentPath: docPath)

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
