import SwiftUI

struct EditSubToolbar: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            ForEach(EditTool.allCases, id: \.self) { tool in
                Button(action: { appState.activeTool = tool }) {
                    Label(tool.rawValue, systemImage: tool.icon)
                        .font(AppTheme.toolbarFont)
                        .foregroundColor(appState.activeTool == tool ? .white : AppTheme.toolInactive)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(appState.activeTool == tool ? AppTheme.toolActive.opacity(0.3) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AppTheme.toolbarBackground.opacity(0.8))
    }
}
