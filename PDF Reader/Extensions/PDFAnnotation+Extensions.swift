import PDFKit
import AppKit

/// Custom stamp annotation that renders a signature image
/// Subclassing ensures the image is drawn into the PDF content stream on save
class SignatureAnnotation: PDFAnnotation {
    var signatureImage: NSImage?

    init(bounds: CGRect, image: NSImage) {
        self.signatureImage = image
        super.init(bounds: bounds, forType: .stamp, withProperties: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(with box: PDFDisplayBox, in context: CGContext) {
        guard let image = signatureImage else {
            super.draw(with: box, in: context)
            return
        }

        context.saveGState()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            context.restoreGState()
            return
        }

        // Draw the image within the annotation bounds
        context.draw(cgImage, in: bounds)
        context.restoreGState()
    }
}

extension PDFAnnotationService {
    /// Place a signature image on the page
    static func addSignature(on page: PDFPage, at point: CGPoint, imageData: Data) -> PDFAnnotation? {
        guard let image = NSImage(data: imageData) else { return nil }

        // Scale to reasonable size (150pt wide, proportional height)
        let targetWidth: CGFloat = 150
        let scale = targetWidth / max(image.size.width, 1)
        let targetHeight = image.size.height * scale
        let bounds = CGRect(
            x: point.x - targetWidth / 2,
            y: point.y - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )

        let annotation = SignatureAnnotation(bounds: bounds, image: image)
        page.addAnnotation(annotation)
        return annotation
    }
}
