import SwiftUI

enum AppTheme {
    // MARK: - Background Colors
    static let windowBackground = Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)) // #1c1c1e
    static let canvasBackground = Color(nsColor: NSColor(red: 0.078, green: 0.078, blue: 0.086, alpha: 1)) // #141416
    static let sidebarBackground = Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1)) // #262628
    static let toolbarBackground = Color(nsColor: NSColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)) // #2c2c2e

    // MARK: - Content Colors
    static let primaryText = Color.white
    static let secondaryText = Color(nsColor: NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1))
    static let accentColor = Color.accentColor
    static let divider = Color.white.opacity(0.1)

    // MARK: - Interactive
    static let toolActive = Color.accentColor
    static let toolInactive = Color(nsColor: NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1))
    static let buttonHover = Color.white.opacity(0.08)

    // MARK: - Annotation
    static let highlightColor = Color.yellow.opacity(0.35)
    static let signatureTint = Color.black

    // MARK: - Fonts
    static let toolbarFont = Font.system(size: 12, weight: .medium)
    static let pageLabelFont = Font.system(size: 11, weight: .regular).monospacedDigit()
}
