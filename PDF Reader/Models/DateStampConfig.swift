import Foundation

enum DateFormat: String, CaseIterable, Identifiable {
    case mmddyyyy = "MM/dd/yyyy"
    case ddmmyyyy = "dd/MM/yyyy"
    case yyyymmdd = "yyyy-MM-dd"
    case long = "MMMM d, yyyy"

    var id: String { rawValue }

    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = rawValue
        return formatter.string(from: Date())
    }

    func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = rawValue
        return formatter.string(from: date)
    }
}
