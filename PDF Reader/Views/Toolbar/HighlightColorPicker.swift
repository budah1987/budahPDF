import SwiftUI
import PDFKit

/// Compact color swatch popover shown after selecting text with the highlight tool.
struct HighlightColorPicker: View {
    @ObservedObject var appState: AppState

    private let colors: [(String, NSColor)] = [
        ("Yellow", NSColor.yellow.withAlphaComponent(0.35)),
        ("Green", NSColor.green.withAlphaComponent(0.30)),
        ("Blue", NSColor.systemBlue.withAlphaComponent(0.25)),
        ("Pink", NSColor.systemPink.withAlphaComponent(0.30)),
        ("Orange", NSColor.orange.withAlphaComponent(0.30)),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(colors, id: \.0) { name, color in
                Button(action: { applyHighlight(color: color) }) {
                    Circle()
                        .fill(Color(nsColor: color.withAlphaComponent(0.8)))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(name)
            }
        }
        .padding(.horizontal, 10)
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

    private func applyHighlight(color: NSColor) {
        for (page, bounds) in appState.pendingHighlightSelections {
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = color
            page.addAnnotation(annotation)
            appState.pushAnnotation(annotation, on: page)
        }
        appState.hasUnsavedChanges = true
        appState.showHighlightColorPicker = false
        appState.pendingHighlightSelections = []
        appState.highlightColorPickerPosition = nil
        appState.needsPDFViewFocus = true
    }
}
