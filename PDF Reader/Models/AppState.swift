import SwiftUI
import PDFKit
import Combine

enum AppMode: String, CaseIterable {
    case view = "View"
    case edit = "Edit"
    case search = "Search"
}

enum EditTool: String, CaseIterable {
    case select = "Select"
    case text = "Text"
    case checkbox = "Checkbox"
    case signature = "Signature"
    case date = "Date"
    case highlight = "Highlight"

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .text: return "textformat"
        case .checkbox: return "checkmark.square"
        case .signature: return "signature"
        case .date: return "calendar"
        case .highlight: return "highlighter"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var mode: AppMode = .view
    @Published var activeTool: EditTool = .select
    @Published var selectedAnnotation: PDFAnnotation?
    @Published var currentPageIndex: Int = 0
    @Published var pageCount: Int = 0
    @Published var zoomLevel: CGFloat = 1.0
    @Published var pdfDocument: PDFDocument?
    @Published var pdfURL: URL?
    @Published var hasUnsavedChanges: Bool = false
    @Published var showFileImporter: Bool = false
    @Published var showSignaturePicker: Bool = false
    @Published var showDatePicker: Bool = false
    @Published var selectedSignatureData: Data?
    @Published var dateClickPoint: CGPoint = .zero

    // Text formatting (persists across annotations until manually changed)
    @Published var textFontName: String = "Helvetica"
    @Published var textFontSize: CGFloat = 14
    @Published var textFontBold: Bool = false
    @Published var textFontItalic: Bool = false

    // Annotation selection position (in global window coordinates for overlay positioning)
    @Published var selectedAnnotationRect: CGRect?

    // Highlight
    @Published var showHighlightColorPicker: Bool = false
    @Published var pendingHighlightSelections: [(PDFPage, CGRect)] = []
    @Published var highlightColorPickerPosition: CGRect? // window coords for popover positioning

    // Focus management
    @Published var needsPDFViewFocus: Bool = false

    // Search
    @Published var searchQuery: String = ""
    @Published var searchResults: [PDFSelection] = []
    @Published var currentSearchResultIndex: Int = 0

    // Undo stack for annotation placement
    var annotationHistory: [(PDFAnnotation, PDFPage)] = []

    var displayTitle: String {
        if let url = pdfURL {
            let name = url.deletingPathExtension().lastPathComponent
            return hasUnsavedChanges ? "\(name) — Edited" : name
        }
        return "budahPDF"
    }

    func openDocument(url: URL) {
        guard let document = PDFDocument(url: url) else { return }
        self.pdfDocument = document
        self.pdfURL = url
        self.pageCount = document.pageCount
        self.currentPageIndex = 0
        self.hasUnsavedChanges = false
        self.mode = .view
        self.annotationHistory.removeAll()
        self.searchResults.removeAll()
        self.searchQuery = ""
        RecentFilesManager.shared.addFile(url: url)
    }

    func pushAnnotation(_ annotation: PDFAnnotation, on page: PDFPage) {
        annotationHistory.append((annotation, page))
        hasUnsavedChanges = true
    }

    func undoLastAnnotation() {
        guard let (annotation, page) = annotationHistory.popLast() else { return }
        page.removeAnnotation(annotation)
        selectedAnnotation = nil
        selectedAnnotationRect = nil
        if annotationHistory.isEmpty {
            hasUnsavedChanges = false
        }
    }

    /// Sync format bar state from a selected annotation's font.
    /// Skips checkmark annotations and Widget fields (which should receive the user's style, not override it).
    func syncFormatFromAnnotation(_ annotation: PDFAnnotation) {
        let type = annotation.type ?? ""
        // Don't sync from Widget fields — we apply the user's style TO them, not FROM them
        if type == "Widget" { return }
        // Don't sync from checkmark annotations
        let contents = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if contents == "✓" { return }
        guard let font = annotation.font else { return }
        let fm = NSFontManager.shared
        let traits = fm.traits(of: font)
        textFontName = font.familyName ?? "Helvetica"
        textFontSize = font.pointSize
        textFontBold = traits.contains(.boldFontMask)
        textFontItalic = traits.contains(.italicFontMask)
    }

    func performSearch() {
        NotificationCenter.default.post(name: .performSearch, object: searchQuery)
    }

    func navigateToSearchResult(at index: Int) {
        guard index >= 0 && index < searchResults.count else { return }
        currentSearchResultIndex = index
        NotificationCenter.default.post(name: .navigateSearchResult, object: index)
    }
}

extension Notification.Name {
    static let performSearch = Notification.Name("performSearch")
    static let navigateSearchResult = Notification.Name("navigateSearchResult")
    static let printDocument = Notification.Name("printDocument")
    static let fitWidth = Notification.Name("fitWidth")
    static let fitPage = Notification.Name("fitPage")
    static let textFormatChanged = Notification.Name("textFormatChanged")
}
