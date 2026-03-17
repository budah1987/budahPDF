import SwiftUI
import PDFKit

/// Floating text format toolbar that appears below a selected annotation.
struct TextFormatBar: View {
    @ObservedObject var appState: AppState

    private let fonts = ["Helvetica", "Times New Roman", "Courier", "Arial", "Georgia", "Verdana"]
    private let sizes: [CGFloat] = [10, 12, 14, 16, 18, 20, 24, 28, 32]

    var body: some View {
        HStack(spacing: 8) {
            // Font picker
            Menu {
                ForEach(fonts, id: \.self) { font in
                    Button(action: {
                        appState.textFontName = font
                        applyFontToSelection()
                    }) {
                        HStack {
                            Text(font)
                            if appState.textFontName == font {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(appState.textFontName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 110)

            divider

            // Size picker
            Menu {
                ForEach(sizes, id: \.self) { size in
                    Button(action: {
                        appState.textFontSize = size
                        applyFontToSelection()
                    }) {
                        HStack {
                            Text("\(Int(size)) pt")
                            if appState.textFontSize == size {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text("\(Int(appState.textFontSize))")
                        .font(.system(size: 11).monospacedDigit())
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 44)

            divider

            // Bold
            Button(action: {
                appState.textFontBold.toggle()
                applyFontToSelection()
            }) {
                Text("B")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(appState.textFontBold ? .white : .secondary)
                    .frame(width: 26, height: 22)
                    .background(
                        appState.textFontBold
                            ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.5))
                            : nil
                    )
            }
            .buttonStyle(.plain)
            .help("Bold (⌘B)")

            // Italic
            Button(action: {
                appState.textFontItalic.toggle()
                applyFontToSelection()
            }) {
                Text("I")
                    .font(.system(size: 12, weight: .regular).italic())
                    .foregroundColor(appState.textFontItalic ? .white : .secondary)
                    .frame(width: 26, height: 22)
                    .background(
                        appState.textFontItalic
                            ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.5))
                            : nil
                    )
            }
            .buttonStyle(.plain)
            .help("Italic (⌘I)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 18)
    }

    private func applyFontToSelection() {
        guard let annotation = appState.selectedAnnotation else { return }
        let type = annotation.type ?? ""
        let isText = type == "FreeText" || (type == "Widget" && annotation.widgetFieldType == .text)
        guard isText else { return }
        let newFont = PDFAnnotationService.buildFont(
            name: appState.textFontName, size: appState.textFontSize,
            bold: appState.textFontBold, italic: appState.textFontItalic
        )
        annotation.font = newFont
        // Resize bounds for our annotations (not native widgets which have fixed bounds)
        if type == "FreeText" {
            let height = max(appState.textFontSize + 10, 22)
            let oldBounds = annotation.bounds
            annotation.bounds = CGRect(x: oldBounds.origin.x, y: oldBounds.origin.y, width: oldBounds.width, height: height)
        }
        appState.hasUnsavedChanges = true
        // Update the live text view if user is currently editing
        NotificationCenter.default.post(name: .textFormatChanged, object: newFont)
    }
}
