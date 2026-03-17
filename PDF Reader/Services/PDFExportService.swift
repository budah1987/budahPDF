import PDFKit
import AppKit

final class PDFExportService {

    /// Save PDF to its original location
    static func save(document: PDFDocument, to url: URL) -> Bool {
        return document.write(to: url)
    }

    /// Save As — write to a new location chosen by user
    static func saveAs(document: PDFDocument, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Document.pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            if document.write(to: url) {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }

    /// Save a flattened copy — renders annotations into page content so they appear in any viewer
    static func saveFlattenedCopy(document: PDFDocument, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Document (Flattened).pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }

            // Create a new PDF by rendering each page with its annotations baked in
            let flatDoc = PDFDocument()
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let bounds = page.bounds(for: .mediaBox)

                let renderer = NSImage(size: bounds.size)
                renderer.lockFocus()
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.setFillColor(NSColor.white.cgColor)
                    ctx.fill(bounds)
                    // Draw the page content + annotations
                    page.draw(with: .mediaBox, to: ctx)
                    // Draw annotations explicitly
                    for annotation in page.annotations {
                        annotation.draw(with: .mediaBox, in: ctx)
                    }
                }
                renderer.unlockFocus()

                // Convert rendered image back to a PDF page
                guard let tiffData = renderer.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]),
                      let nsImage = NSImage(data: pngData) else { continue }

                let imgPage = PDFPage(image: nsImage)
                if let imgPage {
                    flatDoc.insert(imgPage, at: flatDoc.pageCount)
                }
            }

            if flatDoc.write(to: url) {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }

    /// Show share picker anchored to a view
    static func share(pdfURL: URL, from view: NSView) {
        let picker = NSSharingServicePicker(items: [pdfURL])
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
