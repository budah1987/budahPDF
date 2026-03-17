import Foundation

struct SignatureSlot: Codable, Identifiable {
    let id: UUID
    var name: String
    var imageData: Data // PNG
    var dateCreated: Date

    init(name: String, imageData: Data) {
        self.id = UUID()
        self.name = name
        self.imageData = imageData
        self.dateCreated = Date()
    }
}

@MainActor
final class SignatureStore: ObservableObject {
    static let maxSlots = 4
    private static let storageKey = "savedSignatures"

    @Published var slots: [SignatureSlot] = []

    init() {
        load()
    }

    func save(slot: SignatureSlot) {
        if slots.count < Self.maxSlots {
            slots.append(slot)
        }
        persist()
    }

    func remove(at index: Int) {
        guard index < slots.count else { return }
        slots.remove(at: index)
        persist()
    }

    func replace(at index: Int, with slot: SignatureSlot) {
        guard index < slots.count else { return }
        slots[index] = slot
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(slots) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([SignatureSlot].self, from: data) else { return }
        slots = decoded
    }
}
