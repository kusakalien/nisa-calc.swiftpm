import Foundation
import SwiftUI
import Observation

// MARK: - NISAType

enum NISAType: String, Codable, CaseIterable, Identifiable {
    case tsumitate = "つみたて投資枠"
    case growth = "成長投資枠"

    var id: String { rawValue }

    var annualLimit: Int {
        switch self {
        case .tsumitate: 1_200_000
        case .growth:    2_400_000
        }
    }

    var totalLimit: Int {
        switch self {
        case .tsumitate: 6_000_000
        case .growth:    12_000_000
        }
    }

    var color: Color {
        switch self {
        case .tsumitate: .blue
        case .growth:    .green
        }
    }

    var shortName: String {
        switch self {
        case .tsumitate: "つみたて"
        case .growth:    "成長投資"
        }
    }
}

// MARK: - YearMonth

struct YearMonth: Comparable, Hashable, Codable {
    var year: Int
    var month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.year != rhs.year ? lhs.year < rhs.year : lhs.month < rhs.month
    }

    func advanced(by months: Int) -> YearMonth {
        let total = (year * 12 + month - 1) + months
        return YearMonth(year: total / 12, month: total % 12 + 1)
    }

    func next() -> YearMonth { advanced(by: 1) }

    static func current() -> YearMonth {
        let now = Date()
        let c = Calendar.current
        return YearMonth(year: c.component(.year, from: now), month: c.component(.month, from: now))
    }

    var date: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    var displayString: String { "\(year)年\(month)月" }
}

// MARK: - NISAEntry

struct NISAEntry: Identifiable, Codable {
    var id = UUID()
    var type: NISAType
    var start: YearMonth
    var end: YearMonth
    var monthlyAmount: Int

    func covers(_ ym: YearMonth) -> Bool { start <= ym && ym <= end }
}

// MARK: - MonthlyDataPoint

struct MonthlyDataPoint: Identifiable {
    let id = UUID()
    let yearMonth: YearMonth
    let tsumitateTotal: Double
    let growthTotal: Double
    var total: Double { tsumitateTotal + growthTotal }

    var date: Date { yearMonth.date }
}

// MARK: - NISAStore

@Observable
final class NISAStore {
    var entries: [NISAEntry] = [] {
        didSet { save() }
    }

    init() { load() }

    func addEntry(_ entry: NISAEntry) { entries.append(entry) }
    func removeEntries(at offsets: IndexSet) { entries.remove(atOffsets: offsets) }

    func updateEntry(id: UUID, type: NISAType, start: YearMonth, end: YearMonth, monthlyAmount: Int) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].type          = type
        entries[index].start         = start
        entries[index].end           = end
        entries[index].monthlyAmount = monthlyAmount
    }

    // MARK: - Calculation

    func calculateMonthlyData() -> [MonthlyDataPoint] {
        guard !entries.isEmpty else { return [] }

        guard let earliest = entries.map(\.start).min(),
              let latest   = entries.map(\.end).max()
        else { return [] }

        var result: [MonthlyDataPoint] = []
        var tsumitateTotal = 0
        var growthTotal    = 0
        var tsumitateYear  = 0
        var growthYear     = 0
        var trackedYear    = earliest.year

        var ym = earliest
        while ym <= latest {
            if ym.year != trackedYear {
                tsumitateYear = 0
                growthYear    = 0
                trackedYear   = ym.year
            }

            var rawTsumitate = 0
            var rawGrowth    = 0

            for entry in entries where entry.covers(ym) {
                switch entry.type {
                case .tsumitate: rawTsumitate += entry.monthlyAmount
                case .growth:    rawGrowth    += entry.monthlyAmount
                }
            }

            let addTsumitate = min(
                rawTsumitate,
                max(0, NISAType.tsumitate.annualLimit - tsumitateYear),
                max(0, NISAType.tsumitate.totalLimit  - tsumitateTotal)
            )
            let addGrowth = min(
                rawGrowth,
                max(0, NISAType.growth.annualLimit - growthYear),
                max(0, NISAType.growth.totalLimit  - growthTotal)
            )

            tsumitateYear  += addTsumitate
            tsumitateTotal += addTsumitate
            growthYear     += addGrowth
            growthTotal    += addGrowth

            result.append(MonthlyDataPoint(
                yearMonth: ym,
                tsumitateTotal: Double(tsumitateTotal),
                growthTotal:    Double(growthTotal)
            ))

            ym = ym.next()
        }

        return result
    }

    var currentPoint: MonthlyDataPoint? {
        let now  = YearMonth.current()
        let data = calculateMonthlyData()
        return data.last(where: { $0.yearMonth <= now }) ?? data.first
    }

    // MARK: - Persistence

    private let saveKey = "nisaEntries"

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([NISAEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
