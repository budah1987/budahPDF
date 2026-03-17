import Foundation

@MainActor
final class RecentFilesManager: ObservableObject {
    static let shared = RecentFilesManager()

    private static let storageKey = "recentFileBookmarks"
    private static let maxItems = 10

    @Published private(set) var recentFiles: [RecentFile] = []

    struct RecentFile: Codable, Identifiable, Equatable {
        let bookmark: Data
        let name: String
        let dateOpened: Date

        var id: String { name + dateOpened.description }

        /// Resolve the bookmark back to a URL, returning the URL and whether the bookmark is stale
        func resolveURL() -> URL? {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return nil }
            return url
        }
    }

    private init() {
        load()
    }

    func addFile(url: URL) {
        // Create a security-scoped bookmark
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let name = url.deletingPathExtension().lastPathComponent
        var files = recentFiles
        files.removeAll { $0.name == name }
        let entry = RecentFile(
            bookmark: bookmark,
            name: name,
            dateOpened: Date()
        )
        files.insert(entry, at: 0)
        if files.count > Self.maxItems {
            files = Array(files.prefix(Self.maxItems))
        }
        recentFiles = files
        save()
    }

    func clearAll() {
        recentFiles = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let files = try? JSONDecoder().decode([RecentFile].self, from: data) else { return }
        recentFiles = files
    }
}
