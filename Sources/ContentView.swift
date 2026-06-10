import SwiftUI

struct ContentView: View {
    @Environment(NISAStore.self) private var store

    var body: some View {
        TabView {
            SummaryView()
                .tabItem { Label("サマリー", systemImage: "chart.pie.fill") }
            ChartView()
                .tabItem { Label("グラフ", systemImage: "chart.line.uptrend.xyaxis") }
            ReturnSimulationView()
                .tabItem { Label("運用益", systemImage: "yensign.circle.fill") }
            InputView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
    }
}
