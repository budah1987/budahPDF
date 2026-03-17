import SwiftUI
import UniformTypeIdentifiers

@main
struct PDFReaderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var signatureStore = SignatureStore()
    @StateObject private var recentFilesManager = RecentFilesManager.shared

    var body: some Scene {
        Window(appState.displayTitle, id: "main") {
            ContentView(appState: appState, signatureStore: signatureStore)
                .frame(minWidth: 700, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
                .preferredColorScheme(.dark)
                .fileImporter(
                    isPresented: $appState.showFileImporter,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            if url.startAccessingSecurityScopedResource() {
                                appState.openDocument(url: url)
                            }
                        }
                    case .failure:
                        break
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") {
                    appState.showFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)

                Menu("Open Recent") {
                    ForEach(recentFilesManager.recentFiles) { file in
                        Button(file.name) {
                            guard let url = file.resolveURL() else { return }
                            _ = url.startAccessingSecurityScopedResource()
                            appState.openDocument(url: url)
                        }
                    }

                    if !recentFilesManager.recentFiles.isEmpty {
                        Divider()
                        Button("Clear Recent") {
                            recentFilesManager.clearAll()
                        }
                    }
                }
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Print…") {
                    NotificationCenter.default.post(name: .printDocument, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(appState.pdfDocument == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    saveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.pdfDocument == nil)

                Button("Save As…") {
                    saveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.pdfDocument == nil)

                Divider()

                Button("Save Flattened Copy…") {
                    saveFlattenedCopy()
                }
                .disabled(appState.pdfDocument == nil)
            }
            CommandMenu("Mode") {
                Button("View Mode") {
                    appState.mode = .view
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Edit Mode") {
                    appState.mode = .edit
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Search") {
                    appState.mode = .search
                }
                .keyboardShortcut("3", modifiers: .command)
            }
            CommandMenu("Format") {
                Button("Bold") {
                    appState.textFontBold.toggle()
                    applyFontToSelectedAnnotation()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    appState.textFontItalic.toggle()
                    applyFontToSelectedAnnotation()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    appState.zoomLevel = min(appState.zoomLevel + 0.25, 5.0)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button("Zoom Out") {
                    appState.zoomLevel = max(appState.zoomLevel - 0.25, 0.25)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    appState.zoomLevel = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }

    private func saveDocument() {
        guard let document = appState.pdfDocument,
              let url = appState.pdfURL else { return }
        if PDFExportService.save(document: document, to: url) {
            appState.hasUnsavedChanges = false
        }
    }

    private func saveDocumentAs() {
        guard let document = appState.pdfDocument else { return }
        PDFExportService.saveAs(document: document) { newURL in
            if let newURL {
                appState.pdfURL = newURL
                appState.hasUnsavedChanges = false
            }
        }
    }

    private func applyFontToSelectedAnnotation() {
        guard let annotation = appState.selectedAnnotation,
              (annotation.type ?? "") == "FreeText" else { return }
        let newFont = PDFAnnotationService.buildFont(
            name: appState.textFontName, size: appState.textFontSize,
            bold: appState.textFontBold, italic: appState.textFontItalic
        )
        annotation.font = newFont
        let height = max(appState.textFontSize + 10, 22)
        let old = annotation.bounds
        annotation.bounds = CGRect(x: old.origin.x, y: old.origin.y, width: old.width, height: height)
        appState.hasUnsavedChanges = true
        NotificationCenter.default.post(name: .textFormatChanged, object: newFont)
    }

    private func saveFlattenedCopy() {
        guard let document = appState.pdfDocument else { return }
        PDFExportService.saveFlattenedCopy(document: document) { _ in }
    }
}
