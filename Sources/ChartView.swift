import SwiftUI
import Charts

enum ChartDisplayStyle: String, CaseIterable, Identifiable {
    case line       = "推移グラフ"
    case stackedBar = "積み上げ棒グラフ"
    var id: String { rawValue }
}

enum BarGranularity: String, CaseIterable, Identifiable {
    case yearly  = "年単位"
    case monthly = "月単位"
    var id: String { rawValue }
}


struct ChartView: View {
    @Environment(NISAStore.self) private var store
    @State private var selectedPoint: MonthlyDataPoint?
    @State private var selectedPointTitle: String?
    @State private var showTotal = true
    @State private var displayStyle: ChartDisplayStyle = .line
    @State private var barGranularity: BarGranularity = .yearly

    private var chartData: [MonthlyDataPoint] { store.calculateMonthlyData() }

    var body: some View {
        NavigationStack {
            Group {
                if chartData.isEmpty {
                    ContentUnavailableView(
                        "データがありません",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("「設定」タブで積立プランを追加してください")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            stylePicker
                            switch displayStyle {
                            case .line:
                                toggleRow
                                mainChart
                                legendView
                                if let point = selectedPoint {
                                    selectedDetailView(point)
                                }
                            case .stackedBar:
                                stackedBarChart
                                legendView
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("積立グラフ")
            .navigationBarTitleDisplayMode(.large)
            .onChange(of: displayStyle) { _, _ in clearSelection() }
            .onChange(of: barGranularity) { _, _ in clearSelection() }
        }
    }

    // MARK: - Chart

    private var mainChart: some View {
        Chart {
            // Reference lines (limit)
            RuleMark(y: .value("つみたて上限", NISAType.tsumitate.totalLimit.wan))
                .foregroundStyle(.blue.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .annotation(position: .trailing) {
                    Text("つみたて上限")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue.opacity(0.6))
                }

            RuleMark(y: .value("成長上限", NISAType.growth.totalLimit.wan))
                .foregroundStyle(.green.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .annotation(position: .trailing) {
                    Text("成長上限")
                        .font(.system(size: 9))
                        .foregroundStyle(.green.opacity(0.6))
                }

            // つみたて area
            ForEach(chartData) { point in
                AreaMark(
                    x: .value("月", point.date),
                    yStart: .value("下限", 0),
                    yEnd: .value("つみたて", point.tsumitateTotal.wan)
                )
                .foregroundStyle(.blue.opacity(0.2))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("月", point.date),
                    y: .value("つみたて", point.tsumitateTotal.wan),
                    series: .value("種類", NISAType.tsumitate.rawValue)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // 成長投資 area
            ForEach(chartData) { point in
                AreaMark(
                    x: .value("月", point.date),
                    yStart: .value("下限", 0),
                    yEnd: .value("成長投資", point.growthTotal.wan)
                )
                .foregroundStyle(.green.opacity(0.15))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("月", point.date),
                    y: .value("成長投資", point.growthTotal.wan),
                    series: .value("種類", NISAType.growth.rawValue)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // 合計 line
            if showTotal {
                ForEach(chartData) { point in
                    LineMark(
                        x: .value("月", point.date),
                        y: .value("合計", point.total.wan),
                        series: .value("種類", "合計")
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                }
            }

            // 現在月マーカー
            let now = YearMonth.current()
            if let nowPoint = chartData.last(where: { $0.yearMonth <= now }) {
                RuleMark(x: .value("現在", nowPoint.date))
                    .foregroundStyle(.orange.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top) {
                        Text("現在")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
            }

            // Selection indicator
            if let point = selectedPoint {
                RuleMark(x: .value("選択", point.date))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    selectedPoint = nearestPoint(to: date)
                                }
                            }
                            .onEnded { _ in selectedPoint = nil }
                    )
            }
        }
        .frame(height: 320)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Sub-views

    private var stylePicker: some View {
        Picker("表示形式", selection: $displayStyle) {
            ForEach(ChartDisplayStyle.allCases) { style in
                Text(style.rawValue).tag(style)
            }
        }
        .pickerStyle(.segmented)
    }

    private var toggleRow: some View {
        Toggle("合計を表示", isOn: $showTotal)
            .tint(.purple)
            .padding(.horizontal)
    }

    // MARK: - Stacked Bar Chart

    private struct StackedBar: Identifiable {
        let id = UUID()
        let label: String
        let date: Date
        let typeLabel: String
        let amount: Double
    }

    private func yearEndPoint(for year: Int, in data: [MonthlyDataPoint]) -> MonthlyDataPoint? {
        data.last(where: { $0.yearMonth.year == year && $0.yearMonth.month == 12 })
            ?? data.last(where: { $0.yearMonth.year == year })
    }

    private var stackedBarData: [StackedBar] {
        let data = chartData
        guard !data.isEmpty else { return [] }

        var result: [StackedBar] = []

        switch barGranularity {
        case .yearly:
            let years = Array(Set(data.map { $0.yearMonth.year })).sorted()
            for year in years {
                guard let point = yearEndPoint(for: year, in: data) else { continue }
                result.append(StackedBar(label: "\(year)", date: point.date,
                                          typeLabel: NISAType.tsumitate.rawValue, amount: point.tsumitateTotal.wan))
                result.append(StackedBar(label: "\(year)", date: point.date,
                                          typeLabel: NISAType.growth.rawValue, amount: point.growthTotal.wan))
            }
        case .monthly:
            for point in data {
                result.append(StackedBar(label: point.yearMonth.displayString, date: point.date,
                                          typeLabel: NISAType.tsumitate.rawValue, amount: point.tsumitateTotal.wan))
                result.append(StackedBar(label: point.yearMonth.displayString, date: point.date,
                                          typeLabel: NISAType.growth.rawValue, amount: point.growthTotal.wan))
            }
        }
        return result
    }

    private var stackedBarChart: some View {
        VStack(spacing: 12) {
            Picker("単位", selection: $barGranularity) {
                ForEach(BarGranularity.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)

            switch barGranularity {
            case .yearly:
                yearlyBarChart
            case .monthly:
                monthlyBarChart
            }

            if let point = selectedPoint {
                selectedDetailView(point, title: selectedPointTitle)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var yearlyBarChart: some View {
        Chart(stackedBarData) { bar in
            BarMark(
                x: .value("年", bar.date, unit: .year),
                y: .value("金額(万円)", bar.amount)
            )
            .foregroundStyle(by: .value("種類", bar.typeLabel))
        }
        .chartForegroundStyleScale([
            NISAType.tsumitate.rawValue: NISAType.tsumitate.color,
            NISAType.growth.rawValue:    NISAType.growth.color
        ])
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(yearBarSelectionGesture(proxy: proxy, geo: geo))
            }
        }
        .frame(height: 320)
    }

    private var monthlyBarChart: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Chart(stackedBarData) { bar in
                BarMark(
                    x: .value("年月", bar.date, unit: .month),
                    y: .value("金額(万円)", bar.amount),
                    width: .fixed(14)
                )
                .foregroundStyle(by: .value("種類", bar.typeLabel))
            }
            .chartForegroundStyleScale([
                NISAType.tsumitate.rawValue: NISAType.tsumitate.color,
                NISAType.growth.rawValue:    NISAType.growth.color
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 3)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            let c = Calendar.current
                            let label = "\(String(c.component(.year, from: date)))/\(String(c.component(.month, from: date)))"
                            Text(label)
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let x = location.x - geo[proxy.plotFrame!].origin.x
                            if let date: Date = proxy.value(atX: x) {
                                selectedPoint = nearestPoint(to: date)
                                selectedPointTitle = nil
                            }
                        }
                }
            }
            .frame(width: max(400, CGFloat(stackedBarData.count / 2) * 32))
            .frame(height: 300)
        }
    }

    private var legendView: some View {
        HStack(spacing: 20) {
            LegendItem(color: .blue,   label: NISAType.tsumitate.rawValue)
            LegendItem(color: .green,  label: NISAType.growth.rawValue)
            if displayStyle == .line && showTotal {
                LegendItem(color: .purple, label: "合計")
            }
        }
        .font(.caption)
    }

    private func selectedDetailView(_ point: MonthlyDataPoint, title: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title ?? point.yearMonth.displayString)
                .font(.headline)
            HStack {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Text("つみたて: \(Int(point.tsumitateTotal).formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
            }
            HStack {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("成長投資: \(Int(point.growthTotal).formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
            }
            HStack {
                Circle().fill(.purple).frame(width: 8, height: 8)
                Text("合計: \(Int(point.total).formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
                    .bold()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func nearestPoint(to date: Date) -> MonthlyDataPoint? {
        chartData.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private func clearSelection() {
        selectedPoint = nil
        selectedPointTitle = nil
    }

    /// 折れ線グラフ用: タップ位置に最も近い月をそのまま選択
    private func barSelectionGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                if let date: Date = proxy.value(atX: x) {
                    selectedPoint = nearestPoint(to: date)
                    selectedPointTitle = nil
                }
            }
            .onEnded { _ in clearSelection() }
    }

    /// 年単位の積み上げ棒グラフ用: タップ位置の年に対応する「年末時点」のデータを選択
    private func yearBarSelectionGesture(proxy: ChartProxy, geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                let x = drag.location.x - geo[proxy.plotFrame!].origin.x
                guard let date: Date = proxy.value(atX: x) else { return }
                let year = Calendar.current.component(.year, from: date)
                if let point = yearEndPoint(for: year, in: chartData) {
                    selectedPoint = point
                    selectedPointTitle = "\(year)年"
                }
            }
            .onEnded { _ in clearSelection() }
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Double {
    var wan: Double { self / 10_000 }
}

private extension Int {
    var wan: Double { Double(self) / 10_000 }
}
