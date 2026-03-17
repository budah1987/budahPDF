import SwiftUI

struct DatePickerPopover: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var onConfirm: (String) -> Void

    @State private var selectedDate = Date()
    @State private var selectedFormat: DateFormat = .mmddyyyy

    var body: some View {
        VStack(spacing: 16) {
            Text("Insert Date")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)

            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .frame(width: 260)

            Picker("Format", selection: $selectedFormat) {
                ForEach(DateFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.radioGroup)

            // Preview
            Text(selectedFormat.format(date: selectedDate))
                .font(.system(size: 14, design: .monospaced))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.05)))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Insert") {
                    let dateString = selectedFormat.format(date: selectedDate)
                    onConfirm(dateString)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(AppTheme.windowBackground)
    }
}
