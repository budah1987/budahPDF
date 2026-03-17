import SwiftUI
import PDFKit

struct ContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var signatureStore: SignatureStore
    @StateObject private var recentFilesManager = RecentFilesManager.shared
    @State private var pdfView: PDFView?
    var body: some View {
        Group {
            if appState.pdfDocument == nil {
                WelcomeView(appState: appState, recentFilesManager: recentFilesManager)
            } else {
                HStack(spacing: 0) {
                    // Thumbnail sidebar
                    ThumbnailSidebar(pdfView: pdfView)
                        .frame(width: 85)

                    Divider()

                    // PDF canvas with floating toolbar overlay
                    ZStack(alignment: .bottom) {
                        PDFKitViewWrapper(appState: appState, pdfView: $pdfView)
                            .overlay(annotationFormatOverlay)
                            .overlay(highlightColorOverlay)

                        FloatingToolbar(appState: appState)
                            .fixedSize()
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(AppTheme.canvasBackground)
        .background(WindowCloseInterceptor(appState: appState))
        .onReceive(NotificationCenter.default.publisher(for: .goToPage)) { notification in
            if let page = notification.object as? PDFPage {
                pdfView?.go(to: page)
            }
        }
        .sheet(isPresented: $appState.showSignaturePicker, onDismiss: { reclaimPDFViewFocus() }) {
            SignaturePicker(signatureStore: signatureStore) { imageData in
                placeSignature(imageData: imageData)
            }
        }
        .sheet(isPresented: $appState.showDatePicker, onDismiss: { reclaimPDFViewFocus() }) {
            DatePickerPopover(appState: appState) { dateString in
                placeDate(dateString: dateString)
            }
        }
        .onDrop(of: [.pdf], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    appState.openDocument(url: url)
                }
            }
            return true
        }
    }

    private var showFormatBar: Bool {
        guard let ann = appState.selectedAnnotation,
              appState.selectedAnnotationRect != nil else { return false }
        let type = ann.type ?? ""
        if type == "FreeText" {
            // Don't show format bar for checkmark annotations
            let contents = ann.contents?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if contents == "✓" { return false }
            return true
        }
        if type == "Widget" && ann.widgetFieldType == .text { return true }
        return false
    }

    @ViewBuilder
    private var annotationFormatOverlay: some View {
        GeometryReader { geo in
            if showFormatBar, let annotRect = appState.selectedAnnotationRect {
                let localFrame = geo.frame(in: .global)
                // annotRect is in window coords (origin bottom-left)
                // localFrame is in SwiftUI global coords (origin top-left of window)
                let x = annotRect.midX - localFrame.minX
                // Convert y: window bottom-left origin → top-left origin
                let windowContentHeight = NSApp.mainWindow?.contentView?.frame.height ?? (localFrame.minY + localFrame.height)
                let annotTopY = windowContentHeight - annotRect.maxY
                let y = (annotTopY - localFrame.minY) + annotRect.height + 8
                TextFormatBar(appState: appState)
                    .fixedSize()
                    .position(x: x, y: y)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                    .animation(.easeOut(duration: 0.2), value: appState.selectedAnnotationRect)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showFormatBar)
    }

    @ViewBuilder
    private var highlightColorOverlay: some View {
        GeometryReader { geo in
            if appState.showHighlightColorPicker, let annotRect = appState.highlightColorPickerPosition {
                let localFrame = geo.frame(in: .global)
                let x = annotRect.midX - localFrame.minX
                let windowContentHeight = NSApp.mainWindow?.contentView?.frame.height ?? (localFrame.minY + localFrame.height)
                let annotTopY = windowContentHeight - annotRect.maxY
                let y = (annotTopY - localFrame.minY) + annotRect.height + 8

                HighlightColorPicker(appState: appState)
                    .fixedSize()
                    .position(x: x, y: y)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: appState.showHighlightColorPicker)
    }

    private func reclaimPDFViewFocus() {
        appState.needsPDFViewFocus = true
    }

    private func placeSignature(imageData: Data) {
        guard let pdfView = pdfView,
              let page = pdfView.currentPage else { return }
        let point = appState.dateClickPoint
        if let annotation = PDFAnnotationService.addSignature(on: page, at: point, imageData: imageData) {
            appState.pushAnnotation(annotation, on: page)
        }
    }

    private func placeDate(dateString: String) {
        guard let pdfView = pdfView,
              let page = pdfView.currentPage else { return }
        let point = appState.dateClickPoint
        let annotation = PDFAnnotationService.addDateAnnotation(on: page, at: point, dateString: dateString)
        appState.pushAnnotation(annotation, on: page)
    }
}

// MARK: - Window Close Interceptor

/// Invisible NSView that installs a window delegate to intercept close with unsaved changes.
struct WindowCloseInterceptor: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            context.coordinator.originalDelegate = window.delegate
            window.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.appState = appState
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    class Coordinator: NSObject, NSWindowDelegate {
        var appState: AppState
        weak var originalDelegate: NSWindowDelegate?

        init(appState: AppState) {
            self.appState = appState
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard appState.hasUnsavedChanges else { return true }

            let alert = NSAlert()
            alert.messageText = "Save changes before closing?"
            alert.informativeText = "Your annotations will be lost if you don't save."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: // Save
                if let document = appState.pdfDocument, let url = appState.pdfURL {
                    if PDFExportService.save(document: document, to: url) {
                        appState.hasUnsavedChanges = false
                        return true
                    }
                }
                // If no URL yet, fall through to save-as
                guard let document = appState.pdfDocument else { return false }
                PDFExportService.saveAs(document: document) { newURL in
                    if newURL != nil {
                        Task { @MainActor in
                            self.appState.hasUnsavedChanges = false
                        }
                        sender.close()
                    }
                }
                return false
            case .alertSecondButtonReturn: // Don't Save
                appState.hasUnsavedChanges = false
                return true
            default: // Cancel
                return false
            }
        }

        func windowWillClose(_ notification: Notification) {
            originalDelegate?.windowWillClose?(notification)
        }
    }
}
