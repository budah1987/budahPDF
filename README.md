# budahPDF

A fast, private PDF reader and annotation tool for macOS. Built with SwiftUI and PDFKit — no telemetry, no cloud, no third-party dependencies. Your documents stay on your machine.

## Install

1. **Download** the latest release from the [Releases](../../releases) page
2. **Drag** `budahPDF.app` into your Applications folder
3. **Open** — if macOS shows a security warning, go to System Settings → Privacy & Security and click "Open Anyway"

### Build from source

Requires **Xcode 15+** and **macOS 14 (Sonoma)** or later.

```bash
git clone https://github.com/budah1987/budahPDF.git
cd budahPDF
open "PDF Reader.xcodeproj"
```

Select the `budahPDF` scheme in Xcode and press **Cmd+R** to build and run.

## Features

### Read & Navigate
- Smooth continuous vertical scrolling
- Thumbnail sidebar for quick page navigation
- Zoom from 25% to 500% — scroll wheel with Cmd, or use toolbar buttons
- Fit to Width / Fit to Page
- Full-text search with result highlighting and navigation

### Annotate
- **Text** — click anywhere to add a text box with font, size, bold/italic controls
- **Checkmarks** — one-click checkmark placement
- **Signatures** — draw freehand or import an image, save up to 4 signatures
- **Dates** — pick a date and format (MM/dd/yyyy, dd/MM/yyyy, yyyy-MM-dd, or long format)
- **Highlights** — select text and choose from 5 colors (yellow, green, blue, pink, orange)
- **Form filling** — detects and fills interactive PDF form fields (text, checkboxes, radio buttons, dropdowns)

### Save & Export
- **Save** to the original file
- **Save As** to a new location
- **Save Flattened Copy** — bakes annotations into the page content so they appear in any PDF viewer
- **Print** and **Share** via macOS system dialogs

### Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open | Cmd+O |
| Save | Cmd+S |
| Save As | Cmd+Shift+S |
| Print | Cmd+P |
| Search | Cmd+K |
| View Mode | Cmd+1 |
| Edit Mode | Cmd+2 |
| Search Mode | Cmd+3 |
| Zoom In | Cmd+= |
| Zoom Out | Cmd+- |
| Actual Size | Cmd+0 |
| Bold | Cmd+B |
| Italic | Cmd+I |
| Undo | Cmd+Z |
| Delete Annotation | Delete / Backspace |

**Tool shortcuts (in Edit Mode):**

| Tool | Key |
|------|-----|
| Select | V |
| Text | T |
| Checkbox | C |
| Signature | S |
| Date | D |
| Highlight | H |

## Privacy

budahPDF makes **zero network connections**. There is no analytics, no telemetry, no crash reporting, and no cloud sync. The app uses only Apple system frameworks — no third-party code. Your PDFs and signatures are stored locally and never leave your computer.

## Requirements

- macOS 14 (Sonoma) or later

## License

This project is shared with love. Feel free to use it.
