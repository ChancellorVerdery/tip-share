import Foundation

/// Parses and formats shift lengths typed as h:mm.
public enum ShiftTime {
    /// Minutes for "6:30", "6", ":45" or "630" (3–4 digits read as h:mm). Nil for anything else.
    public static func minutes(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let parts = t.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            guard t.allSatisfy(\.isNumber) else { return nil }
            if t.count >= 3 {
                // "630" → 6:30, "1015" → 10:15
                guard t.count <= 4, let h = Int(t.dropLast(2)), let m = Int(t.suffix(2)), m < 60 else { return nil }
                return h * 60 + m
            }
            return Int(t).map { $0 * 60 }
        case 2:
            let hText = parts[0].isEmpty ? "0" : String(parts[0])
            guard hText.allSatisfy(\.isNumber), parts[1].count == 2, parts[1].allSatisfy(\.isNumber),
                  let h = Int(hText), let m = Int(parts[1]), m < 60 else { return nil }
            return h * 60 + m
        default:
            return nil
        }
    }

    public static func format(_ minutes: Int) -> String {
        "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }
}
