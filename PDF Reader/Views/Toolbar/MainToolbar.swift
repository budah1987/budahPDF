import SwiftUI

struct FloatingToolbar: View {
    @ObservedObject var appState: AppState
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Mode Picker: View, Edit
            HStack(spacing: 2) {
                modeButton(for: .view)
                modeButton(for: .edit)
            }

            toolbarDivider

            // Search: magnifying glass that expands into search field
            searchSection

            // Edit tools (only in edit mode, hidden during search)
            if appState.mode == .edit {
                toolbarDivider

                HStack(spacing: 4) {
                    ForEach(EditTool.allCases, id: \.self) { tool in
                        Button(action: { appState.activeTool = tool }) {
                            VStack(spacing: 2) {
                                Image(systemName: tool.icon)
                                    .font(.system(size: 12))
                                Text(tool.rawValue)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundColor(appState.activeTool == tool ? .white : .secondary)
                            .frame(width: 44, height: 34)
                            .background(
                                Group {
                                    if appState.activeTool == tool {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color.accentColor.opacity(0.5))
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .help(tool.rawValue)
                    }
                }
            }

            toolbarDivider

            // Page Navigation
            HStack(spacing: 6) {
                Button(action: previousPage) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(appState.currentPageIndex <= 0 ? .secondary.opacity(0.3) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(appState.currentPageIndex <= 0)

                Text(pageLabel)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.secondary)

                Button(action: nextPage) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(appState.currentPageIndex >= appState.pageCount - 1 ? .secondary.opacity(0.3) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(appState.currentPageIndex >= appState.pageCount - 1)
            }

            toolbarDivider

            // Zoom Controls
            HStack(spacing: 6) {
                RepeatButton(action: zoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text(zoomLabel)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 34)

                RepeatButton(action: zoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                toolbarDivider

                Button(action: fitWidth) {
                    Text("Width")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .help("Fit to Width")

                Button(action: fitPage) {
                    Text("Page")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                .help("Fit Whole Page")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        )
        .animation(.easeInOut(duration: 0.25), value: appState.mode)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack(spacing: 0) {
            // Magnifying glass — always visible, toggles search
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if appState.mode == .search {
                        appState.mode = .view
                        appState.searchQuery = ""
                        appState.searchResults = []
                    } else {
                        appState.mode = .search
                        isSearchFocused = true
                    }
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(appState.mode == .search ? .white : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Group {
                            if appState.mode == .search {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.accentColor)
                            }
                        }
                    )
            }
            .buttonStyle(.plain)
            .zIndex(1)

            // Search field slides out from the magnifying glass
            if appState.mode == .search {
                HStack(spacing: 4) {
                    TextField("Search...", text: $appState.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .focused($isSearchFocused)
                        .onSubmit {
                            appState.performSearch()
                        }
                        .onChange(of: appState.searchQuery) { _, newValue in
                            if newValue.isEmpty {
                                appState.searchResults = []
                                appState.performSearch()
                            }
                        }

                    if !appState.searchResults.isEmpty {
                        Text("\(appState.currentSearchResultIndex + 1)/\(appState.searchResults.count)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundColor(.secondary)
                            .fixedSize()

                        Button(action: previousSearchResult) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button(action: nextSearchResult) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 180)
                .padding(.leading, 6)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
            }
        }
    }

    // MARK: - Subviews

    private func modeButton(for mode: AppMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                appState.mode = mode
                if mode != .search {
                    appState.searchQuery = ""
                    appState.searchResults = []
                }
            }
        }) {
            Text(mode.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(appState.mode == mode ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Group {
                        if appState.mode == mode {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 8)
    }

    // MARK: - Labels

    private var pageLabel: String {
        guard appState.pageCount > 0 else { return "—" }
        return "\(appState.currentPageIndex + 1) / \(appState.pageCount)"
    }

    private var zoomLabel: String {
        "\(Int(appState.zoomLevel * 100))%"
    }

    // MARK: - Actions

    private func previousPage() {
        if appState.currentPageIndex > 0 {
            appState.currentPageIndex -= 1
            navigateToCurrentPage()
        }
    }

    private func nextPage() {
        if appState.currentPageIndex < appState.pageCount - 1 {
            appState.currentPageIndex += 1
            navigateToCurrentPage()
        }
    }

    private func navigateToCurrentPage() {
        guard let document = appState.pdfDocument,
              let page = document.page(at: appState.currentPageIndex) else { return }
        NotificationCenter.default.post(
            name: .goToPage,
            object: page
        )
    }

    private func zoomIn() {
        appState.zoomLevel = min(appState.zoomLevel + 0.1, 5.0)
    }

    private func zoomOut() {
        appState.zoomLevel = max(appState.zoomLevel - 0.1, 0.25)
    }

    private func fitWidth() {
        NotificationCenter.default.post(name: .fitWidth, object: nil)
    }

    private func fitPage() {
        NotificationCenter.default.post(name: .fitPage, object: nil)
    }

    private func previousSearchResult() {
        let newIndex = appState.currentSearchResultIndex > 0
            ? appState.currentSearchResultIndex - 1
            : appState.searchResults.count - 1
        appState.navigateToSearchResult(at: newIndex)
    }

    private func nextSearchResult() {
        let newIndex = appState.currentSearchResultIndex < appState.searchResults.count - 1
            ? appState.currentSearchResultIndex + 1
            : 0
        appState.navigateToSearchResult(at: newIndex)
    }
}

extension Notification.Name {
    static let goToPage = Notification.Name("goToPage")
}

// MARK: - Repeat Button

/// A button that fires once on click, then repeatedly while held down.
struct RepeatButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var timer: Timer?
    @State private var isPressed = false

    var body: some View {
        label()
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        action()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            DispatchQueue.main.async {
                                self.timer?.invalidate()
                                self.timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
                                    DispatchQueue.main.async {
                                        action()
                                    }
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        timer?.invalidate()
                        timer = nil
                    }
            )
    }
}
