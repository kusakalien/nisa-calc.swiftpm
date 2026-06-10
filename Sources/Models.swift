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

// MARK: - EndMode

enum EndMode: Codable, Hashable {
    case fixedDate(YearMonth)
    case untilLimitReached
}

// MARK: - NISAEntry

struct NISAEntry: Identifiable, Codable {
    var id = UUID()
    var type: NISAType
    var isSpot: Bool = false       // true: スポット購入(個別株など)、false: 積立
    var start: YearMonth           // 積立: 開始年月 / スポット: 購入年月
    var endMode: EndMode = .fixedDate(YearMonth(year: 2024, month: 12))
    var amount: Int                // 積立: 毎月の金額 / スポット: 購入金額
    var memo: String = ""          // スポット購入時のメモ(銘柄など)

    /// 日付範囲計算用の見積もり終了年月(「満額になるまで」の場合は概算)
    var effectiveEnd: YearMonth {
        if isSpot { return start }
        switch endMode {
        case .fixedDate(let end):
            return end
        case .untilLimitReached:
            guard amount > 0 else { return start }
            let months = (type.totalLimit + amount - 1) / amount
            return start.advanced(by: max(0, months - 1))
        }
    }

    func covers(_ ym: YearMonth) -> Bool {
        if isSpot { return ym == start }
        switch endMode {
        case .fixedDate(let end):
            return start <= ym && ym <= end
        case .untilLimitReached:
            return start <= ym
        }
    }
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

// MARK: - ProjectionPoint

/// 運用益シミュレーション結果の各月のデータ
struct ProjectionPoint: Identifiable {
    let id = UUID()
    let yearMonth: YearMonth
    let principal: Double   // 投資元本(累計)
    let value: Double       // 運用後の評価額(複利)
    var gain: Double { value - principal }  // 運用益

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

    func updateEntry(_ entry: NISAEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
    }

    // MARK: - Calculation

    func calculateMonthlyData() -> [MonthlyDataPoint] {
        guard !entries.isEmpty else { return [] }

        guard let earliest = entries.map(\.start).min(),
              let latest   = entries.map(\.effectiveEnd).max()
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
                case .tsumitate: rawTsumitate += entry.amount
                case .growth:    rawGrowth    += entry.amount
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

    /// 想定年利(%)をもとに、毎月の積立元本を複利運用した場合の評価額を計算する
    /// - Parameter annualRatePercent: 想定年利(%)。例: 5.0
    /// - Returns: 各月の元本・評価額の推移
    func calculateProjection(annualRatePercent: Double) -> [ProjectionPoint] {
        let monthlyData = calculateMonthlyData()
        guard !monthlyData.isEmpty else { return [] }

        let monthlyRate = annualRatePercent / 100.0 / 12.0

        var value = 0.0
        var previousPrincipal = 0.0
        var result: [ProjectionPoint] = []

        for point in monthlyData {
            // その月に新たに投じられた元本
            let contribution = max(0, point.total - previousPrincipal)
            // 前月までの評価額を1か月分運用し、当月の積立を加える
            value = value * (1 + monthlyRate) + contribution
            previousPrincipal = point.total

            result.append(ProjectionPoint(
                yearMonth: point.yearMonth,
                principal: point.total,
                value: value
            ))
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
