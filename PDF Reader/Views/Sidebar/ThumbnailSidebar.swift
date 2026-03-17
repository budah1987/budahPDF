import SwiftUI
import PDFKit

struct ThumbnailSidebar: NSViewRepresentable {
    let pdfView: PDFView?

    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnailView = PDFThumbnailView()
        thumbnailView.thumbnailSize = CGSize(width: 60, height: 80)
        thumbnailView.backgroundColor = NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)
        return thumbnailView
    }

    func updateNSView(_ thumbnailView: PDFThumbnailView, context: Context) {
        thumbnailView.pdfView = pdfView
    }
}
