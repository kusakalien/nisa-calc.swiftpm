import SwiftUI

struct ContentView: View {
    @Environment(NISAStore.self) private var store

    var body: some View {
        TabView {
            Tab("サマリー", systemImage: "chart.pie.fill") {
                SummaryView()
            }
            Tab("グラフ", systemImage: "chart.line.uptrend.xyaxis") {
                ChartView()
            }
            Tab("設定", systemImage: "gearshape.fill") {
                InputView()
            }
        }
    }
}
