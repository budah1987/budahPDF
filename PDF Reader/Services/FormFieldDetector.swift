import PDFKit

struct FormFieldInfo {
    let annotation: PDFAnnotation
    let page: PDFPage
    let pageIndex: Int
    let fieldType: FieldType

    enum FieldType {
        case textField
        case checkbox
        case radioButton
        case dropdown
        case other
    }
}

final class FormFieldDetector {

    /// Scan all pages for interactive widget annotations
    static func detectFields(in document: PDFDocument) -> [FormFieldInfo] {
        var fields: [FormFieldInfo] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations {
                guard annotation.type == "Widget" else { continue }
                let fieldType = classifyWidget(annotation)
                fields.append(FormFieldInfo(
                    annotation: annotation,
                    page: page,
                    pageIndex: i,
                    fieldType: fieldType
                ))
            }
        }
        return fields
    }

    /// Check if a document has any interactive form fields
    static func hasFormFields(in document: PDFDocument) -> Bool {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if page.annotations.contains(where: { $0.type == "Widget" }) {
                return true
            }
        }
        return false
    }

    private static func classifyWidget(_ annotation: PDFAnnotation) -> FormFieldInfo.FieldType {
        let widgetFieldType = annotation.widgetFieldType
        switch widgetFieldType {
        case .button:
            if annotation.buttonWidgetStateString == "Off" || annotation.buttonWidgetStateString == "Yes" {
                return .checkbox
            }
            return .radioButton
        case .text:
            return .textField
        case .choice:
            return .dropdown
        default:
            return .other
        }
    }
}
