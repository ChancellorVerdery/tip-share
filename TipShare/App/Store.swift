import Foundation
import Observation
import TipShareCore

struct PersonEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = ""
    var time = ""
    var envelope = false

    var minutes: Int? { ShiftTime.minutes(time) }
}

enum Mode: String, Codable, CaseIterable {
    case total = "Total"
    case bills = "Bills"
}

/// Everything on screen, saved to UserDefaults so the staff list and counts survive relaunches.
@Observable
final class Store {
    private struct Saved: Codable {
        var mode: Mode
        var people: [PersonEntry]
        var totalText: String
        var bills: [Int: Int]
    }

    private static let key = "TipShare.state"

    var mode: Mode = .total { didSet { save() } }
    var people: [PersonEntry] = [PersonEntry()] { didSet { save() } }
    var totalText = "" { didSet { save() } }
    var bills: [Int: Int] = [:] { didSet { save() } }

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        mode = saved.mode
        people = saved.people
        totalText = saved.totalText
        bills = saved.bills
    }

    private func save() {
        let saved = Saved(mode: mode, people: people, totalText: totalText, bills: bills)
        if let data = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// The typed total, rounded to the nearest dollar.
    var totalDollars: Int? {
        let cleaned = totalText.filter { $0.isNumber || $0 == "." }
        guard let value = Double(cleaned) else { return nil }
        return Int(value.rounded())
    }

    var billsTotal: Int { bills.reduce(0) { $0 + $1.key * $1.value } }

    var split: Split {
        let workers = people.map { Worker(minutes: $0.minutes ?? 0, envelope: $0.envelope) }
        switch mode {
        case .total: return TipSplitter.split(total: totalDollars ?? 0, workers: workers)
        case .bills: return TipSplitter.split(bills: bills, workers: workers)
        }
    }

    var totalMinutes: Int { people.compactMap(\.minutes).reduce(0, +) }

    func clearTimes() {
        for i in people.indices { people[i].time = "" }
    }

    func clearTips() {
        totalText = ""
        bills = [:]
    }

    func summary() -> String {
        let split = split
        var lines = ["Tip share — $\(split.total) over \(ShiftTime.format(totalMinutes))"]
        for (person, share) in zip(people, split.shares) {
            var line = "\(person.name.isEmpty ? "Unnamed" : person.name) (\(person.minutes.map(ShiftTime.format) ?? "–")): $\(share.amount)"
            if !share.bills.isEmpty { line += " — " + TipSplitter.describe(share.bills) }
            if share.amount < share.target { line += " (short $\(share.target - share.amount))" }
            lines.append(line)
        }
        if !split.leftover.isEmpty { lines.append("Not split: " + TipSplitter.describe(split.leftover)) }
        return lines.joined(separator: "\n")
    }
}
