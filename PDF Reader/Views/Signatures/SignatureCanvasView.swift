import SwiftUI
import AppKit

/// NSView that captures freehand drawing for signatures
class SignatureDrawingView: NSView {
    var strokes: [[CGPoint]] = []
    private var currentStroke: [CGPoint] = []
    var onStrokesChanged: (() -> Void)?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        dirtyRect.fill()

        NSColor.black.setStroke()

        for stroke in strokes {
            drawStroke(stroke)
        }
        if !currentStroke.isEmpty {
            drawStroke(currentStroke)
        }
    }

    private func drawStroke(_ points: [CGPoint]) {
        guard points.count > 1 else { return }
        let path = NSBezierPath()
        path.lineWidth = 2.0
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.move(to: points[0])

        if points.count == 2 {
            path.line(to: points[1])
        } else {
            for i in 1..<points.count - 1 {
                let mid = CGPoint(
                    x: (points[i].x + points[i + 1].x) / 2,
                    y: (points[i].y + points[i + 1].y) / 2
                )
                path.curve(to: mid, controlPoint1: points[i], controlPoint2: points[i])
            }
            path.line(to: points[points.count - 1])
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke = [point]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentStroke.append(point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if currentStroke.count > 1 {
            strokes.append(currentStroke)
        }
        currentStroke = []
        needsDisplay = true
        onStrokesChanged?()
    }

    func clear() {
        strokes = []
        currentStroke = []
        needsDisplay = true
        onStrokesChanged?()
    }

    /// Export strokes as cropped PNG Data
    func exportPNG() -> Data? {
        guard !strokes.isEmpty else { return nil }

        // Find bounding box
        let allPoints = strokes.flatMap { $0 }
        guard !allPoints.isEmpty else { return nil }

        let minX = allPoints.map(\.x).min()! - 4
        let minY = allPoints.map(\.y).min()! - 4
        let maxX = allPoints.map(\.x).max()! + 4
        let maxY = allPoints.map(\.y).max()! + 4
        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        let image = NSImage(size: cropRect.size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: cropRect.size).fill()

        let transform = NSAffineTransform()
        transform.translateX(by: -cropRect.origin.x, yBy: -cropRect.origin.y)
        transform.concat()

        NSColor.black.setStroke()
        for stroke in strokes {
            drawStroke(stroke)
        }

        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return pngData
    }
}

/// SwiftUI wrapper for the signature drawing canvas
struct SignatureCanvasView: NSViewRepresentable {
    @Binding var hasStrokes: Bool
    var drawingView = SignatureDrawingView()

    func makeNSView(context: Context) -> SignatureDrawingView {
        drawingView.onStrokesChanged = {
            DispatchQueue.main.async {
                self.hasStrokes = !drawingView.strokes.isEmpty
            }
        }
        return drawingView
    }

    func updateNSView(_ nsView: SignatureDrawingView, context: Context) {}

    func clear() {
        drawingView.clear()
    }

    func exportPNG() -> Data? {
        drawingView.exportPNG()
    }
}
