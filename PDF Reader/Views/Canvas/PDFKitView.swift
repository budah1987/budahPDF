import SwiftUI
import PDFKit

/// PDFView subclass that intercepts clicks for annotation placement
class AnnotatablePDFView: PDFView {
    var appState: AppState?
    var needsFirstResponder = false

    // Drag-to-move state
    private var dragAnnotation: PDFAnnotation?
    private var dragPage: PDFPage?
    private var dragOffset: CGPoint = .zero

    // Selection highlight
    private var selectionHighlightLayer: CAShapeLayer?
    private var lastHighlightViewRect: CGRect?

    // Text editing overlay
    var editingTextView: NSTextView?
    private var editingAnnotation: PDFAnnotation?

    func beginEditingAnnotation(_ annotation: PDFAnnotation, on page: PDFPage) {
        endEditingAnnotation()

        // Sync format bar to reflect this annotation's font
        if let appState = appState {
            MainActor.assumeIsolated {
                appState.syncFormatFromAnnotation(annotation)
            }
        }

        let annotBounds = annotation.bounds
        let viewRect = convert(annotBounds, from: page)

        let scrollView = NSScrollView(frame: viewRect)
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: NSRect(origin: .zero, size: viewRect.size))
        textView.string = annotation.contents ?? ""
        textView.font = annotation.font
        textView.textColor = annotation.fontColor ?? .black
        textView.backgroundColor = annotation.color.withAlphaComponent(0.01)
        textView.drawsBackground = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isFieldEditor = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.maxSize = NSSize(width: viewRect.width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        addSubview(scrollView)
        window?.makeFirstResponder(textView)

        editingTextView = textView
        editingAnnotation = annotation
        annotation.contents = ""  // hide PDFKit's rendered text while overlay is active
    }

    func endEditingAnnotation() {
        guard let textView = editingTextView,
              let annotation = editingAnnotation else { return }
        annotation.contents = textView.string
        // Explicitly restore font from appState (PDFKit may reset font when contents was cleared)
        if let appState = appState {
            annotation.font = PDFAnnotationService.buildFont(
                name: appState.textFontName, size: appState.textFontSize,
                bold: appState.textFontBold, italic: appState.textFontItalic
            )
        }
        // Remove the scroll view parent
        textView.enclosingScrollView?.removeFromSuperview()
        editingTextView = nil
        editingAnnotation = nil
        MainActor.assumeIsolated {
            appState?.hasUnsavedChanges = true
        }
    }

    /// Compute the window-space rect for an annotation (for SwiftUI overlay positioning)
    func annotationWindowRect(for annotation: PDFAnnotation, on page: PDFPage) -> CGRect? {
        let viewRect = convert(annotation.bounds, from: page)
        return self.convert(viewRect, to: nil) // window coordinates (origin at bottom-left)
    }

    func updateSelectionHighlight() {
        guard let appState = appState,
              let annotation = appState.selectedAnnotation,
              let page = annotation.page else {
            selectionHighlightLayer?.removeFromSuperlayer()
            selectionHighlightLayer = nil
            lastHighlightViewRect = nil
            // Defer clearing to avoid mutating @Published state during updateNSView
            if appState?.selectedAnnotationRect != nil {
                DispatchQueue.main.async {
                    self.appState?.selectedAnnotationRect = nil
                }
            }
            return
        }

        let pageBounds = annotation.bounds
        let viewRect = convert(pageBounds, from: page)

        // Only recreate the highlight layer if the rect actually changed (avoids flutter during typing)
        if viewRect != lastHighlightViewRect {
            selectionHighlightLayer?.removeFromSuperlayer()
            selectionHighlightLayer = nil

            let layer = CAShapeLayer()
            layer.path = CGPath(roundedRect: viewRect.insetBy(dx: -3, dy: -3), cornerWidth: 2, cornerHeight: 2, transform: nil)
            layer.strokeColor = NSColor.controlAccentColor.cgColor
            layer.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            layer.lineWidth = 1.5
            layer.lineDashPattern = [4, 3]

            self.layer?.addSublayer(layer)
            selectionHighlightLayer = layer
            lastHighlightViewRect = viewRect
        }

        // Keep toolbar position in sync during scroll/zoom (deferred to avoid state mutation during updateNSView)
        let windowRect = self.convert(viewRect, to: nil)
        if appState.selectedAnnotationRect != windowRect {
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                MainActor.assumeIsolated {
                    appState.selectedAnnotationRect = windowRect
                }
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Cursor management

    override func resetCursorRects() {
        guard let appState = appState, appState.mode == .edit else {
            super.resetCursorRects()
            return
        }
        switch appState.activeTool {
        case .text:
            discardCursorRects()
            addCursorRect(visibleRect, cursor: .iBeam)
        case .checkbox, .signature, .date:
            discardCursorRects()
            addCursorRect(visibleRect, cursor: .crosshair)
        case .select, .highlight:
            super.resetCursorRects()
        }
    }

    /// Force-update the cursor immediately (e.g. after tool switch via keyboard)
    func refreshCursor() {
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        // End text editing overlay if clicking outside it
        if let textView = editingTextView {
            let clickInView = convert(event.locationInWindow, from: nil)
            let scrollFrame = textView.enclosingScrollView?.frame ?? textView.frame
            if !scrollFrame.contains(clickInView) {
                endEditingAnnotation()
            }
        }

        guard let appState = appState else {
            super.mouseDown(with: event)
            return
        }

        // In any mode: detect clicks on Widget text fields for format bar
        let locationInView = convert(event.locationInWindow, from: nil)
        if let page = page(for: locationInView, nearest: true) {
            let pointOnPage = convert(locationInView, to: page)
            let hitWidget = page.annotations.reversed().first { annotation in
                let type = annotation.type ?? ""
                return type == "Widget" && annotation.widgetFieldType == .text &&
                       annotation.bounds.insetBy(dx: -6, dy: -6).contains(pointOnPage)
            }
            if let widget = hitWidget {
                MainActor.assumeIsolated {
                    appState.selectedAnnotation = widget
                    let rect = annotationWindowRect(for: widget, on: page)
                    appState.selectedAnnotationRect = rect
                }
                // Apply persisted font style to the widget
                let font = PDFAnnotationService.buildFont(
                    name: appState.textFontName, size: appState.textFontSize,
                    bold: appState.textFontBold, italic: appState.textFontItalic
                )
                widget.font = font
                NotificationCenter.default.post(name: .textFormatChanged, object: font)
                super.mouseDown(with: event)
                return
            }
        }

        // In any mode (except edit+select which handles its own selection + drag): detect clicks on FreeText annotations for format bar
        if !(appState.mode == .edit && appState.activeTool == .select),
           let page = page(for: locationInView, nearest: true) {
            let pointOnPage = convert(locationInView, to: page)
            let hitFreeText = page.annotations.reversed().first { annotation in
                let type = annotation.type ?? ""
                return type == "FreeText" &&
                       annotation.bounds.insetBy(dx: -6, dy: -6).contains(pointOnPage)
            }
            if let freeText = hitFreeText {
                MainActor.assumeIsolated {
                    appState.selectedAnnotation = freeText
                    appState.syncFormatFromAnnotation(freeText)
                    let rect = annotationWindowRect(for: freeText, on: page)
                    appState.selectedAnnotationRect = rect
                }
                return
            }
        }

        // Only intercept further in edit mode
        guard appState.mode == .edit else {
            super.mouseDown(with: event)
            return
        }

        // Select tool: hit-test our annotations
        if appState.activeTool == .select {
            if let page = page(for: locationInView, nearest: true) {
                let pointOnPage = convert(locationInView, to: page)
                let hitAnnotation = page.annotations.reversed().first { annotation in
                    let type = annotation.type ?? ""
                    guard type != "Widget" else { return false }
                    return annotation.bounds.insetBy(dx: -6, dy: -6).contains(pointOnPage)
                }
                MainActor.assumeIsolated {
                    appState.selectedAnnotation = hitAnnotation
                    // Sync format bar to match the selected annotation's font
                    if let hit = hitAnnotation, (hit.type ?? "") == "FreeText" {
                        appState.syncFormatFromAnnotation(hit)
                    }
                    if let hit = hitAnnotation, let hitPage = hit.page,
                       let rect = annotationWindowRect(for: hit, on: hitPage) {
                        appState.selectedAnnotationRect = rect
                    }
                }
                if let hit = hitAnnotation {
                    // Double-click on FreeText → re-edit
                    if event.clickCount == 2, (hit.type ?? "") == "FreeText" {
                        beginEditingAnnotation(hit, on: page)
                        return
                    }
                    // Single click → select + start drag
                    dragAnnotation = hit
                    dragPage = page
                    dragOffset = CGPoint(
                        x: pointOnPage.x - hit.bounds.origin.x,
                        y: pointOnPage.y - hit.bounds.origin.y
                    )
                    return
                }
            }
            dragAnnotation = nil
            super.mouseDown(with: event)
            return
        }

        // For highlight tool, let PDFView handle text selection natively
        if appState.activeTool == .highlight {
            super.mouseDown(with: event)
            return
        }

        guard let page = page(for: locationInView, nearest: true) else {
            super.mouseDown(with: event)
            return
        }
        let pointOnPage = convert(locationInView, to: page)

        MainActor.assumeIsolated {
            switch appState.activeTool {
            case .select:
                break
            case .text:
                let annotation = PDFAnnotationService.addTextAnnotation(
                    on: page, at: pointOnPage,
                    fontName: appState.textFontName, fontSize: appState.textFontSize,
                    bold: appState.textFontBold, italic: appState.textFontItalic
                )
                appState.pushAnnotation(annotation, on: page)
                appState.selectedAnnotation = annotation
                let rect = annotationWindowRect(for: annotation, on: page)
                appState.selectedAnnotationRect = rect
                appState.activeTool = .select
                // Start editing overlay directly
                DispatchQueue.main.async {
                    self.beginEditingAnnotation(annotation, on: page)
                }
            case .checkbox:
                let annotation = PDFAnnotationService.addCheckmark(on: page, at: pointOnPage)
                appState.pushAnnotation(annotation, on: page)
                self.needsFirstResponder = true
            case .signature:
                appState.dateClickPoint = pointOnPage
                appState.showSignaturePicker = true
            case .date:
                appState.dateClickPoint = pointOnPage
                appState.showDatePicker = true
            case .highlight:
                break
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let annotation = dragAnnotation,
              let page = dragPage else {
            super.mouseDragged(with: event)
            return
        }
        let locationInView = convert(event.locationInWindow, from: nil)
        let pointOnPage = convert(locationInView, to: page)
        let newOrigin = CGPoint(
            x: pointOnPage.x - dragOffset.x,
            y: pointOnPage.y - dragOffset.y
        )
        annotation.bounds = CGRect(origin: newOrigin, size: annotation.bounds.size)
    }

    override func mouseUp(with event: NSEvent) {
        if dragAnnotation != nil {
            dragAnnotation = nil
            dragPage = nil
            MainActor.assumeIsolated {
                appState?.hasUnsavedChanges = true
            }
            return
        }

        // Highlight tool: capture text selection and show color picker
        if let appState = appState, appState.mode == .edit, appState.activeTool == .highlight {
            if let selection = currentSelection {
                var selections: [(PDFPage, CGRect)] = []
                for pageIndex in 0..<(document?.pageCount ?? 0) {
                    guard let page = document?.page(at: pageIndex) else { continue }
                    let selectionForPage = selection.selectionsByLine()
                    for lineSel in selectionForPage {
                        let bounds = lineSel.bounds(for: page)
                        if bounds.width > 0 && bounds.height > 0 {
                            selections.append((page, bounds))
                        }
                    }
                }
                if !selections.isEmpty {
                    // Compute popover position from the last selection bounds
                    let (lastPage, lastBounds) = selections.last!
                    let viewRect = convert(lastBounds, from: lastPage)
                    let windowRect = self.convert(viewRect, to: nil)
                    MainActor.assumeIsolated {
                        appState.pendingHighlightSelections = selections
                        appState.highlightColorPickerPosition = windowRect
                        appState.showHighlightColorPicker = true
                    }
                }
            }
            super.mouseUp(with: event)
            return
        }

        super.mouseUp(with: event)
    }

    // MARK: - Scroll wheel zoom

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            guard let appState = appState else { return }
            let factor: CGFloat = event.hasPreciseScrollingDeltas ? 0.005 : 0.03
            let delta = event.scrollingDeltaY * factor
            let newScale = min(max(self.scaleFactor + delta, 0.25), 5.0)
            // Set appState directly — updateNSView will apply scaleFactor
            appState.zoomLevel = newScale
            return
        }
        super.scrollWheel(with: event)
    }

    // MARK: - Keyboard handling

    /// Check if a text annotation is currently being edited (user is typing in a field)
    private var isEditingText: Bool {
        if editingTextView != nil { return true }
        guard let window = self.window else { return false }
        // If the first responder is a text view inside this PDFView, user is editing an annotation
        if let responder = window.firstResponder as? NSTextView,
           responder.isDescendant(of: self) {
            return true
        }
        return false
    }

    override func keyDown(with event: NSEvent) {
        let hasCmd = event.modifierFlags.contains(.command)
        let key = event.charactersIgnoringModifiers ?? ""

        // Tab: let PDFKit handle navigation, then apply user's font to the new Widget field
        if event.keyCode == 48 {
            super.keyDown(with: event)
            // After PDFKit moves focus to the next Widget, apply user's font style
            DispatchQueue.main.async { [weak self] in
                guard let self, let appState = self.appState else { return }
                // Find which Widget is now focused by checking the first responder's parent annotation
                guard let responder = self.window?.firstResponder as? NSTextView,
                      responder.isDescendant(of: self) else { return }
                // Find the Widget annotation under the responder
                let responderFrame = responder.convert(responder.bounds, to: self)
                for pageIndex in 0..<(self.document?.pageCount ?? 0) {
                    guard let page = self.document?.page(at: pageIndex) else { continue }
                    for annotation in page.annotations where annotation.type == "Widget" && annotation.widgetFieldType == .text {
                        let viewRect = self.convert(annotation.bounds, from: page)
                        if viewRect.intersects(responderFrame) {
                            MainActor.assumeIsolated {
                                appState.selectedAnnotation = annotation
                                if let rect = self.annotationWindowRect(for: annotation, on: page) {
                                    appState.selectedAnnotationRect = rect
                                }
                            }
                            let font = PDFAnnotationService.buildFont(
                                name: appState.textFontName, size: appState.textFontSize,
                                bold: appState.textFontBold, italic: appState.textFontItalic
                            )
                            annotation.font = font
                            responder.font = font
                            return
                        }
                    }
                }
            }
            return
        }

        // Escape: always handled by us
        if event.keyCode == 53 {
            if editingTextView != nil {
                endEditingAnnotation()
                return
            }
            if !isEditingText {
                MainActor.assumeIsolated {
                    appState?.selectedAnnotation = nil
                    appState?.mode = .view
                }
                refreshCursor()
                return
            }
            // If editing text (PDFKit native), exit the text editor
            self.window?.makeFirstResponder(self)
            return
        }

        // When editing text inside an annotation, pass everything else to the text view
        if isEditingText {
            super.keyDown(with: event)
            return
        }

        // --- Below only runs when NOT editing text ---

        // Cmd+Z: undo last annotation placement
        if hasCmd && key == "z" {
            MainActor.assumeIsolated {
                appState?.undoLastAnnotation()
            }
            return
        }

        // Cmd+K: search
        if hasCmd && key == "k" {
            MainActor.assumeIsolated {
                appState?.mode = .search
            }
            return
        }

        // Delete or Backspace removes selected annotation
        if event.keyCode == 51 || event.keyCode == 117 {
            guard let appState = appState,
                  let annotation = appState.selectedAnnotation,
                  let page = annotation.page else {
                super.keyDown(with: event)
                return
            }
            page.removeAnnotation(annotation)
            MainActor.assumeIsolated {
                appState.selectedAnnotation = nil
                appState.hasUnsavedChanges = true
            }
            return
        }

        // Tool shortcuts — only when not editing text and no modifiers held
        if !isEditingText && !hasCmd && !event.modifierFlags.contains(.control) && !event.modifierFlags.contains(.option) {
            guard let appState = appState else {
                super.keyDown(with: event)
                return
            }
            switch key.lowercased() {
            case "v":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .select
                }
                refreshCursor()
                return
            case "t":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .text
                }
                refreshCursor()
                return
            case "s":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .signature
                }
                refreshCursor()
                return
            case "d":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .date
                }
                refreshCursor()
                return
            case "c":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .checkbox
                }
                refreshCursor()
                return
            case "h":
                MainActor.assumeIsolated {
                    appState.mode = .edit
                    appState.activeTool = .highlight
                }
                refreshCursor()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }
}

/// NSViewRepresentable that wraps AnnotatablePDFView
struct PDFKitViewWrapper: NSViewRepresentable {
    @ObservedObject var appState: AppState
    @Binding var pdfView: PDFView?

    func makeNSView(context: Context) -> AnnotatablePDFView {
        let view = AnnotatablePDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = false
        view.backgroundColor = NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 1)
        view.interpolationQuality = .high
        view.appState = appState
        context.coordinator.pdfView = view

        DispatchQueue.main.async {
            self.pdfView = view
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: view
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleSearch),
            name: .performSearch,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleNavigateResult),
            name: .navigateSearchResult,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePrint),
            name: .printDocument,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFitWidth),
            name: .fitWidth,
            object: nil
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFitPage),
            name: .fitPage,
            object: nil
        )

        // Real-time text editing sync
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange),
            name: NSText.didChangeNotification,
            object: nil
        )

        // Live font updates from format bar
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleTextFormatChanged),
            name: .textFormatChanged,
            object: nil
        )

        return view
    }

    func updateNSView(_ view: AnnotatablePDFView, context: Context) {
        view.appState = appState
        view.window?.invalidateCursorRects(for: view)

        if view.document !== appState.pdfDocument {
            view.document = appState.pdfDocument
            if let document = appState.pdfDocument {
                // Scroll to top of first page, then fit width
                if let firstPage = document.page(at: 0) {
                    let topLeft = CGPoint(x: 0, y: firstPage.bounds(for: view.displayBox).maxY)
                    let destination = PDFDestination(page: firstPage, at: topLeft)
                    view.go(to: destination)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .fitWidth, object: nil)
                }
            }
        }

        // Apply zoom — zoomLevel IS the scaleFactor directly
        let target = appState.zoomLevel
        if abs(view.scaleFactor - target) > 0.001 {
            view.endEditingAnnotation()
            view.scaleFactor = target
        }

        // Clear search highlights when not in search mode
        if appState.mode != .search {
            view.highlightedSelections = nil
            view.currentSelection = nil
        }

        // Update selection highlight
        view.wantsLayer = true
        view.updateSelectionHighlight()

        // Reclaim first responder after placing annotations / closing sheets so Cmd+Z works
        let shouldReclaimFocus = view.needsFirstResponder || appState.needsPDFViewFocus
        if appState.pdfDocument != nil && shouldReclaimFocus {
            view.needsFirstResponder = false
            if appState.needsPDFViewFocus { appState.needsPDFViewFocus = false }
            DispatchQueue.main.async {
                if let window = view.window,
                   window.firstResponder !== view,
                   !(window.firstResponder is NSTextView) {
                    window.makeFirstResponder(view)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    class Coordinator: NSObject {
        let appState: AppState
        weak var pdfView: PDFView?
        init(appState: AppState) {
            self.appState = appState
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let index = document.index(for: currentPage)
            MainActor.assumeIsolated {
                self.appState.currentPageIndex = index
            }
        }

        @objc func handleSearch(_ notification: Notification) {
            guard let query = notification.object as? String,
                  let pdfView = pdfView,
                  let document = pdfView.document,
                  !query.isEmpty else {
                pdfView?.highlightedSelections = nil
                MainActor.assumeIsolated {
                    self.appState.searchResults = []
                    self.appState.currentSearchResultIndex = 0
                }
                return
            }

            let selections = document.findString(query, withOptions: .caseInsensitive)
            // Show non-current results as blue highlights, current as yellow via currentSelection
            if let first = selections.first {
                pdfView.currentSelection = first
                pdfView.highlightedSelections = Array(selections.dropFirst())
                pdfView.go(to: first)
            } else {
                pdfView.currentSelection = nil
                pdfView.highlightedSelections = nil
            }

            MainActor.assumeIsolated {
                self.appState.searchResults = selections
                self.appState.currentSearchResultIndex = 0
            }
        }

        @objc func handleNavigateResult(_ notification: Notification) {
            guard let index = notification.object as? Int,
                  let pdfView = pdfView else { return }
            MainActor.assumeIsolated {
                let results = self.appState.searchResults
                guard index >= 0 && index < results.count else { return }
                // Current result shown as yellow (currentSelection), others as blue (highlightedSelections)
                pdfView.currentSelection = results[index]
                var others = results
                others.remove(at: index)
                pdfView.highlightedSelections = others
                pdfView.go(to: results[index])
            }
        }

        @objc func handleFitWidth(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let page = pdfView.currentPage else { return }
            let pageWidth = page.bounds(for: pdfView.displayBox).width
            let viewWidth = pdfView.bounds.width - 40 // account for margins
            let newScale = viewWidth / pageWidth
            pdfView.scaleFactor = newScale
            MainActor.assumeIsolated {
                self.appState.zoomLevel = newScale
            }
        }

        @objc func handleFitPage(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let page = pdfView.currentPage else { return }
            let pageBounds = page.bounds(for: pdfView.displayBox)
            let viewBounds = pdfView.bounds
            let scaleW = (viewBounds.width - 40) / pageBounds.width
            let scaleH = (viewBounds.height - 40) / pageBounds.height
            let newScale = min(scaleW, scaleH)
            pdfView.scaleFactor = newScale
            MainActor.assumeIsolated {
                self.appState.zoomLevel = newScale
            }
        }

        @objc func handlePrint(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let document = pdfView.document else { return }
            guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = true
            printInfo.scalingFactor = 1.0
            if let printOp = document.printOperation(for: printInfo, scalingMode: .pageScaleToFit, autoRotate: true) {
                printOp.showsPrintPanel = true
                printOp.showsProgressPanel = true
                printOp.run()
            }
        }

        @objc func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let pdfView = pdfView as? AnnotatablePDFView,
                  textView.isDescendant(of: pdfView) else { return }
            // Skip if this is our editing overlay — we sync on endEditing instead
            if textView === pdfView.editingTextView { return }
            // Sync live text back to the annotation so it stays current (Widget fields, etc.)
            MainActor.assumeIsolated {
                if let annotation = self.appState.selectedAnnotation {
                    annotation.contents = textView.string
                    self.appState.hasUnsavedChanges = true
                }
            }
        }

        @objc func handleTextFormatChanged(_ notification: Notification) {
            guard let pdfView = pdfView as? AnnotatablePDFView,
                  let font = notification.object as? NSFont else { return }
            // Update the editing overlay or PDFKit's native text view
            if let editingTV = pdfView.editingTextView {
                editingTV.font = font
            } else if let responder = pdfView.window?.firstResponder as? NSTextView,
                      responder.isDescendant(of: pdfView) {
                responder.font = font
            }
        }
    }
}
