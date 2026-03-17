import SwiftUI

struct WelcomeView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var recentFilesManager: RecentFilesManager
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon & title
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.accentColor.opacity(0.8))

                Text("budahPDF")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)

                Text("Open a PDF to get started")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Drop zone + open button
            VStack(spacing: 16) {
                Button(action: { appState.showFileImporter = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                        Text("Open PDF")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)

                Text("or drag and drop a file here")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.top, 28)
            .padding(.bottom, 36)
            .frame(maxWidth: 340)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isDragOver ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isDragOver ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isDragOver ? Color.accentColor.opacity(0.05) : Color.clear)
                    )
            )
            .onDrop(of: [.pdf], isTargeted: $isDragOver) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: "com.adobe.pdf", options: nil) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in
                        appState.openDocument(url: url)
                    }
                }
                return true
            }

            // Recent files
            if !recentFilesManager.recentFiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    VStack(spacing: 2) {
                        ForEach(recentFilesManager.recentFiles) { file in
                            Button(action: { openRecentFile(file) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentColor.opacity(0.7))
                                        .frame(width: 16)

                                    Text(file.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Text(relativeDate(file.dateOpened))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.001)) // hit target
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                    }
                }
                .frame(width: 340)
                .padding(.top, 28)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvasBackground)
    }

    private func openRecentFile(_ file: RecentFilesManager.RecentFile) {
        guard let url = file.resolveURL() else { return }
        _ = url.startAccessingSecurityScopedResource()
        appState.openDocument(url: url)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
