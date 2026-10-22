import Foundation

/// Bill values the app counts, largest first.
public let denominations = [100, 50, 20, 10, 5, 1]

public struct Worker: Hashable {
    public var minutes: Int
    public var envelope: Bool
    public init(minutes: Int, envelope: Bool = false) {
        self.minutes = minutes
        self.envelope = envelope
    }
}

public struct Share: Hashable {
    /// Whole-dollar share by time worked.
    public var target: Int
    /// Dollars actually handed out (equals target unless bills could not be split).
    public var amount: Int
    /// Bill value → count. Empty in total mode.
    public var bills: [Int: Int]
}

public struct Split: Hashable {
    public var shares: [Share]
    /// Bills nobody could take without being overpaid; break them and recount.
    public var leftover: [Int: Int]
    public var total: Int
}

public enum TipSplitter {
    /// Splits `units` by `weights` (largest remainder), so the parts always add up to `units`.
    public static func apportion(_ units: Int, weights: [Int]) -> [Int] {
        let sum = weights.reduce(0, +)
        guard sum > 0, units > 0 else { return weights.map { _ in 0 } }
        var parts = weights.map { units * $0 / sum }
        let remainders = weights.indices.map { (units * weights[$0]) % sum }
        let order = weights.indices.sorted { remainders[$0] != remainders[$1] ? remainders[$0] > remainders[$1] : $0 < $1 }
        for i in order.prefix(units - parts.reduce(0, +)) { parts[i] += 1 }
        return parts
    }

    /// Total mode: `dollars` (already rounded) split by time.
    public static func split(total dollars: Int, workers: [Worker]) -> Split {
        let targets = apportion(dollars, weights: workers.map(\.minutes))
        return Split(shares: targets.map { Share(target: $0, amount: $0, bills: [:]) }, leftover: [:], total: dollars)
    }

    /// Bills mode. Shares are whole dollars by time. Envelope workers are paid first in the fewest bills
    /// (largest bills first); the rest of the bills are dealt out one at a time, largest first, to whichever
    /// remaining worker is owed the most and can take that bill without being overpaid.
    public static func split(bills: [Int: Int], workers: [Worker]) -> Split {
        let total = bills.reduce(0) { $0 + $1.key * max($1.value, 0) }
        let targets = apportion(total, weights: workers.map(\.minutes))
        var pool = bills.filter { $0.value > 0 }
        var given = workers.map { _ in [Int: Int]() }
        var owed = targets

        let envelopes = workers.indices.filter { workers[$0].envelope }
            .sorted { targets[$0] != targets[$1] ? targets[$0] > targets[$1] : $0 < $1 }
        for i in envelopes {
            for d in denominations {
                let take = min(pool[d] ?? 0, owed[i] / d)
                guard take > 0 else { continue }
                given[i][d, default: 0] += take
                pool[d]! -= take
                owed[i] -= take * d
            }
        }

        let others = workers.indices.filter { !workers[$0].envelope }
        var leftover: [Int: Int] = [:]
        for d in denominations {
            for _ in 0..<(pool[d] ?? 0) {
                let pick = others.filter { owed[$0] >= d }.max { a, b in
                    owed[a] != owed[b] ? owed[a] < owed[b] : a > b
                }
                if let i = pick {
                    given[i][d, default: 0] += 1
                    owed[i] -= d
                } else {
                    leftover[d, default: 0] += 1
                }
            }
        }

        let shares = workers.indices.map { Share(target: targets[$0], amount: targets[$0] - owed[$0], bills: given[$0]) }
        return Split(shares: shares, leftover: leftover, total: total)
    }

    /// "2×$20 · 1×$5"
    public static func describe(_ bills: [Int: Int]) -> String {
        denominations.compactMap { d in (bills[d] ?? 0) > 0 ? "\(bills[d]!)×$\(d)" : nil }.joined(separator: " · ")
    }
}
