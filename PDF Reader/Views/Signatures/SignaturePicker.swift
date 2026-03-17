import SwiftUI
import UniformTypeIdentifiers

struct SignaturePicker: View {
    @ObservedObject var signatureStore: SignatureStore
    @Environment(\.dismiss) private var dismiss
    var onSelect: (Data) -> Void

    @State private var showDrawSheet = false
    @State private var showImportPanel = false
    @State private var editingSlotIndex: Int?

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Signature")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Existing signatures
                ForEach(Array(signatureStore.slots.enumerated()), id: \.element.id) { index, slot in
                    signatureCard(slot: slot, index: index)
                }

                // Empty slots
                if signatureStore.slots.count < SignatureStore.maxSlots {
                    emptySlotCard
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(AppTheme.windowBackground)
        .sheet(isPresented: $showDrawSheet) {
            SignatureDrawSheet(signatureStore: signatureStore, slotIndex: editingSlotIndex)
        }
    }

    private func signatureCard(slot: SignatureSlot, index: Int) -> some View {
        VStack(spacing: 6) {
            if let nsImage = NSImage(data: slot.imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
                    .padding(8)
            }
            Text(slot.name)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.divider))
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect(slot.imageData)
            dismiss()
        }
        .contextMenu {
            Button("Replace…") {
                editingSlotIndex = index
                showDrawSheet = true
            }
            Button("Delete", role: .destructive) {
                signatureStore.remove(at: index)
            }
        }
    }

    private var emptySlotCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(AppTheme.secondaryText)
            Text("New Signature")
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.divider, style: StrokeStyle(lineWidth: 1, dash: [4])))
        .contentShape(Rectangle())
        .onTapGesture {
            editingSlotIndex = nil
            showDrawSheet = true
        }
    }
}

struct SignatureDrawSheet: View {
    @ObservedObject var signatureStore: SignatureStore
    let slotIndex: Int?
    @Environment(\.dismiss) private var dismiss

    @State private var signatureName = "My Signature"
    @State private var hasStrokes = false
    @State private var canvas = SignatureCanvasView(hasStrokes: .constant(false))

    var body: some View {
        VStack(spacing: 16) {
            Text(slotIndex != nil ? "Replace Signature" : "Draw Signature")
                .font(.headline)

            // Drawing area
            SignatureCanvasWrapper(hasStrokes: $hasStrokes)
                .frame(height: 120)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.divider))

            TextField("Name", text: $signatureName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            HStack(spacing: 12) {
                Button("Import Image…") {
                    importImage()
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveSignature()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasStrokes)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onReceive(NotificationCenter.default.publisher(for: .signatureExported)) { notification in
            guard let data = notification.object as? Data else { return }
            let slot = SignatureSlot(name: signatureName, imageData: data)
            if let index = slotIndex {
                signatureStore.replace(at: index, with: slot)
            } else {
                signatureStore.save(slot: slot)
            }
            dismiss()
        }
    }

    private func saveSignature() {
        // Trigger export from the canvas, which posts .signatureExported when done
        NotificationCenter.default.post(name: .exportSignature, object: nil)
    }

    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let image = NSImage(contentsOf: url) else { return }

            // Resize to standard height
            let targetHeight: CGFloat = 100
            let scale = targetHeight / image.size.height
            let targetSize = CGSize(width: image.size.width * scale, height: targetHeight)
            let resized = NSImage(size: targetSize)
            resized.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: targetSize))
            resized.unlockFocus()

            guard let tiffData = resized.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            let slot = SignatureSlot(name: signatureName, imageData: pngData)
            if let index = slotIndex {
                signatureStore.replace(at: index, with: slot)
            } else {
                signatureStore.save(slot: slot)
            }
            dismiss()
        }
    }
}

/// Wrapper view that manages its own drawing view and exports
struct SignatureCanvasWrapper: NSViewRepresentable {
    @Binding var hasStrokes: Bool

    func makeNSView(context: Context) -> SignatureDrawingView {
        let view = SignatureDrawingView()
        view.onStrokesChanged = {
            DispatchQueue.main.async {
                self.hasStrokes = !view.strokes.isEmpty
            }
        }
        context.coordinator.drawingView = view

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.exportSignature),
            name: .exportSignature,
            object: nil
        )

        return view
    }

    func updateNSView(_ nsView: SignatureDrawingView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        weak var drawingView: SignatureDrawingView?

        @objc func exportSignature() {
            guard let view = drawingView, let data = view.exportPNG() else { return }
            NotificationCenter.default.post(name: .signatureExported, object: data)
        }
    }
}

extension Notification.Name {
    static let exportSignature = Notification.Name("exportSignature")
    static let signatureExported = Notification.Name("signatureExported")
}
