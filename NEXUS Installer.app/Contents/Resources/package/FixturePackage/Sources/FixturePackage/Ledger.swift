// FixturePackage — demo target with seeded defects for NEXUS to fix
// Defect A (compile): wrong return type in calculateTotal
// Defect B (logic): off-by-one in roundHalfEven

import Foundation

public struct Ledger {
    public private(set) var entries: [Entry] = []

    public struct Entry {
        public let amount: Double
        public let description: String
        public let timestamp: Date

        public init(amount: Double, description: String) {
            self.amount = amount
            self.description = description
            self.timestamp = Date()
        }
    }

    public init() {}

    public mutating func add(_ entry: Entry) {
        entries.append(entry)
    }

    // DEFECT A (compile): returns String instead of Double — causes compile error
    // Fix: change return type to Double and return total
    public func calculateTotal() -> String {
        let total = entries.reduce(0) { $0 + $1.amount }
        return "\(total)"
    }

    // DEFECT B (logic): off-by-one in roundHalfEven
    // For 0.5 should round to 0 (banker's rounding), but returns 1
    // Fix: implement proper banker's rounding
    public func roundHalfEven(_ value: Double) -> Int {
        let rounded = Int(value.rounded())
        if value - Double(Int(value)) == 0.5 {
            return rounded + 1  // BUG: always rounds up on .5
        }
        return rounded
    }

    public func average() -> Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map { $0.amount }.reduce(0, +) / Double(entries.count)
    }
}