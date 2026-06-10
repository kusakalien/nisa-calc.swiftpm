import SwiftUI
import Charts

struct ReturnSimulationView: View {
    @Environment(NISAStore.self) private var store
    @Environment(StoreManager.self) private var storeManager

    @State private var annualRate: Double = 5.0

    var body: some View {
        NavigationStack {
            Group {
                if storeManager.isReturnSimulationUnlocked {
                    unlockedContent
                } else {
                    PaywallView()
                }
            }
            .navigationTitle("運用益シミュレーション")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Unlocked content

    private var projection: [ProjectionPoint] {
        store.calculateProjection(annualRatePercent: annualRate)
    }

    @ViewBuilder
    private var unlockedContent: some View {
        if projection.isEmpty {
            ContentUnavailableView(
                "データがありません",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("「設定」タブで積立プランを追加してください")
            )
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    rateSection
                    resultSummary
                    projectionChart
                    disclaimer
                }
                .padding()
            }
        }
    }

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("想定年利")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f%%", annualRate))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.green)
            }
            Slider(value: $annualRate, in: 0...15, step: 0.5)
                .tint(.green)
            HStack {
                Text("0%")
                Spacer()
                Text("15%")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var resultSummary: some View {
        let last = projection.last
        return VStack(spacing: 12) {
            if let last {
                resultRow(label: "投資元本", value: last.principal, color: .secondary)
                resultRow(label: "運用益", value: last.gain, color: .green)
                Divider()
                resultRow(label: "最終評価額", value: last.value, color: .primary, emphasized: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func resultRow(label: String, value: Double, color: Color, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(Int(value).formatted(.currency(code: "JPY").precision(.fractionLength(0))))
                .font(emphasized ? .title2.bold() : .body)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }

    private var projectionChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("資産推移(元本 vs 評価額)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Chart {
                ForEach(projection) { point in
                    AreaMark(
                        x: .value("年月", point.date),
                        yStart: .value("元本", point.principal.wan),
                        yEnd: .value("評価額", point.value.wan)
                    )
                    .foregroundStyle(.green.opacity(0.15))
                    .interpolationMethod(.monotone)
                }

                ForEach(projection) { point in
                    LineMark(
                        x: .value("年月", point.date),
                        y: .value("評価額", point.value.wan),
                        series: .value("種類", "評価額")
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }

                ForEach(projection) { point in
                    LineMark(
                        x: .value("年月", point.date),
                        y: .value("元本", point.principal.wan),
                        series: .value("種類", "元本")
                    )
                    .foregroundStyle(.gray)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .year)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(String(Calendar.current.component(.year, from: date)))
                                .font(.system(size: 9))
                                .fixedSize()
                                .rotationEffect(.degrees(-45))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(String(Int(v)) + "万")
                        }
                    }
                }
            }
            .frame(height: 300)

            HStack(spacing: 20) {
                LegendDot(color: .green, label: "評価額", dashed: false)
                LegendDot(color: .gray, label: "元本", dashed: true)
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var disclaimer: some View {
        Text("※ 本シミュレーションは想定年利で毎月複利運用した場合の試算であり、将来の運用成果を保証するものではありません。実際の運用には価格変動リスクがあります。")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

// MARK: - Paywall

private struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .padding(.top, 32)

                Text("運用益シミュレーション")
                    .font(.title2.bold())

                Text("想定年利を設定すると、毎月の積立を複利で運用した場合に資産が将来いくらになるかをグラフで確認できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "percent", text: "想定年利を自由に設定")
                    FeatureRow(icon: "chart.xyaxis.line", text: "元本と評価額の推移をグラフ表示")
                    FeatureRow(icon: "yensign.circle", text: "将来の運用益・最終評価額を試算")
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                purchaseButton

                Button("購入を復元") {
                    Task { await storeManager.restore() }
                }
                .font(.subheadline)
                .disabled(storeManager.isProcessing)

                if let error = storeManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Text("一度ご購入いただくと、追加料金なしで永続的にご利用いただけます。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await storeManager.purchase() }
        } label: {
            HStack {
                if storeManager.isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(buttonTitle)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.green, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .disabled(storeManager.isProcessing || storeManager.product == nil)
        .padding(.horizontal)
    }

    private var buttonTitle: String {
        if let price = storeManager.displayPrice {
            return "\(price) で購入"
        }
        return "購入する"
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String
    let dashed: Bool

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
                .opacity(dashed ? 0.6 : 1)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Double {
    var wan: Double { self / 10_000 }
}
