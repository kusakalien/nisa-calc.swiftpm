import SwiftUI

struct SummaryView: View {
    @Environment(NISAStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    currentStatusSection
                    limitsSection
                }
                .padding()
            }
            .navigationTitle("NISA サマリー")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var currentStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let now = YearMonth.current()
            Text("\(now.displayString) 時点")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let point = store.currentPoint {
                HStack(spacing: 16) {
                    AmountCard(
                        title: NISAType.tsumitate.rawValue,
                        amount: Int(point.tsumitateTotal),
                        limit: NISAType.tsumitate.totalLimit,
                        color: NISAType.tsumitate.color
                    )
                    AmountCard(
                        title: NISAType.growth.rawValue,
                        amount: Int(point.growthTotal),
                        limit: NISAType.growth.totalLimit,
                        color: NISAType.growth.color
                    )
                }

                TotalCard(
                    tsumitate: Int(point.tsumitateTotal),
                    growth: Int(point.growthTotal)
                )
            } else {
                ContentUnavailableView(
                    "設定がありません",
                    systemImage: "plus.circle",
                    description: Text("「設定」タブで積立プランを追加してください")
                )
                .frame(height: 200)
            }
        }
    }

    private var limitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("制度の上限")
                .font(.headline)

            LimitRow(
                type: .tsumitate,
                annualLimit: NISAType.tsumitate.annualLimit,
                totalLimit:  NISAType.tsumitate.totalLimit
            )
            LimitRow(
                type: .growth,
                annualLimit: NISAType.growth.annualLimit,
                totalLimit:  NISAType.growth.totalLimit
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Sub-views

private struct AmountCard: View {
    let title: String
    let amount: Int
    let limit: Int
    let color: Color

    private var progress: Double { min(1.0, Double(amount) / Double(limit)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(amount.formatted(.currency(code: "JPY").precision(.fractionLength(0))))
                .font(.title2.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            ProgressView(value: progress)
                .tint(color)

            Text("上限: \(limit.manEnDisplay)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TotalCard: View {
    let tsumitate: Int
    let growth: Int

    private var total: Int { tsumitate + growth }
    private var totalLimit: Int { NISAType.tsumitate.totalLimit + NISAType.growth.totalLimit }
    private var progress: Double { min(1.0, Double(total) / Double(totalLimit)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("合計投資額")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(total.formatted(.currency(code: "JPY").precision(.fractionLength(0))))
                .font(.largeTitle.bold())

            ProgressView(value: progress)
                .tint(.purple)
                .scaleEffect(x: 1, y: 1.5)

            HStack {
                Text("上限: \(totalLimit.manEnDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))% 達成")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct LimitRow: View {
    let type: NISAType
    let annualLimit: Int
    let totalLimit: Int

    var body: some View {
        HStack {
            Circle()
                .fill(type.color)
                .frame(width: 10, height: 10)
            Text(type.rawValue)
                .font(.subheadline)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("年間 \(annualLimit.manEnDisplay)")
                Text("生涯 \(totalLimit.manEnDisplay)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

extension Int {
    var manEnDisplay: String {
        if self >= 10_000 {
            let man = self / 10_000
            let remaining = (self % 10_000) / 1_000
            if remaining > 0 {
                return "\(man)万\(remaining)千円"
            }
            return "\(man)万円"
        }
        return "\(self)円"
    }
}
