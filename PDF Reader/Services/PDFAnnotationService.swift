import PDFKit
import AppKit

final class PDFAnnotationService {

    /// Build an NSFont from name/size/bold/italic
    static func buildFont(name: String, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let fm = NSFontManager.shared
        var font = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        if bold { font = fm.convert(font, toHaveTrait: .boldFontMask) }
        if italic { font = fm.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }

    /// Place a freeText annotation at the given point on the page
    static func addTextAnnotation(on page: PDFPage, at point: CGPoint, text: String = "",
                                   fontName: String = "Helvetica", fontSize: CGFloat = 14,
                                   bold: Bool = false, italic: Bool = false) -> PDFAnnotation {
        let font = buildFont(name: fontName, size: fontSize, bold: bold, italic: italic)
        let height = max(fontSize + 10, 22)
        let bounds = CGRect(x: point.x - 2, y: point.y - height / 2, width: 200, height: height)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.font = font
        annotation.fontColor = .black
        annotation.color = .clear
        annotation.alignment = .left
        let border = PDFBorder()
        border.lineWidth = 0
        annotation.border = border
        page.addAnnotation(annotation)
        return annotation
    }

    /// Place a checkmark annotation at the given point
    static func addCheckmark(on page: PDFPage, at point: CGPoint) -> PDFAnnotation {
        let bounds = CGRect(x: point.x - 8, y: point.y - 8, width: 18, height: 18)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = "✓"
        annotation.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        annotation.fontColor = .black
        annotation.color = .clear
        annotation.alignment = .center
        page.addAnnotation(annotation)
        return annotation
    }

    /// Place a date annotation at the given point
    static func addDateAnnotation(on page: PDFPage, at point: CGPoint, dateString: String) -> PDFAnnotation {
        let bounds = CGRect(x: point.x - 2, y: point.y - 8, width: 150, height: 20)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = dateString
        annotation.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        annotation.fontColor = .black
        annotation.color = .clear
        annotation.alignment = .left
        page.addAnnotation(annotation)
        return annotation
    }

    /// Add highlight annotation over a selection
    static func addHighlight(on page: PDFPage, bounds: CGRect) -> PDFAnnotation {
        let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        annotation.color = NSColor.yellow.withAlphaComponent(0.35)
        page.addAnnotation(annotation)
        return annotation
    }
}
