import SwiftUI

struct InputView: View {
    @Environment(NISAStore.self) private var store
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "積立プランがありません",
                        systemImage: "plus.circle",
                        description: Text("右上の「+」ボタンで追加してください")
                    )
                } else {
                    List {
                        ForEach(store.entries) { entry in
                            EntryRow(entry: entry)
                        }
                        .onDelete { store.removeEntries(at: $0) }
                    }
                }
            }
            .navigationTitle("積立プラン")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("追加", systemImage: "plus") {
                        showingAddSheet = true
                    }
                }
                if !store.entries.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEntrySheet()
            }
        }
    }
}

// MARK: - EntryRow

private struct EntryRow: View {
    let entry: NISAEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.type.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.type.rawValue)
                    .font(.subheadline.bold())
                Text("\(entry.start.displayString) 〜 \(entry.end.displayString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.monthlyAmount.formatted(.currency(code: "JPY").precision(.fractionLength(0))) + "/月")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddEntrySheet

struct AddEntrySheet: View {
    @Environment(NISAStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: NISAType = .tsumitate
    @State private var startYear  = 2024
    @State private var startMonth = 1
    @State private var endYear    = 2028
    @State private var endMonth   = 12
    @State private var amountText = "100000"
    @State private var errorMessage: String?

    private let years = Array(2024...2050)
    private let months = Array(1...12)

    private var monthlyAmount: Int { Int(amountText) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("投資枠") {
                    Picker("種類", selection: $selectedType) {
                        ForEach(NISAType.allCases) { type in
                            Label(type.rawValue, systemImage: "circle.fill")
                                .foregroundStyle(type.color)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("開始年月") {
                    HStack {
                        Picker("年", selection: $startYear) {
                            ForEach(years, id: \.self) { Text("\($0)年") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("月", selection: $startMonth) {
                            ForEach(months, id: \.self) { Text("\($0)月") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: 100)
                    }
                    .frame(height: 120)
                }

                Section("終了年月") {
                    HStack {
                        Picker("年", selection: $endYear) {
                            ForEach(years, id: \.self) { Text("\($0)年") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("月", selection: $endMonth) {
                            ForEach(months, id: \.self) { Text("\($0)月") }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: 100)
                    }
                    .frame(height: 120)
                }

                Section("毎月の積立額") {
                    HStack {
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("例: 100000", text: $amountText)
                            .keyboardType(.numberPad)
                    }

                    limitHint
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("積立プランを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { addEntry() }
                        .disabled(monthlyAmount <= 0)
                }
            }
        }
    }

    // MARK: - Helpers

    private var limitHint: some View {
        let monthly = selectedType.annualLimit / 12
        return Text("月額上限の目安: \(monthly.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func addEntry() {
        let start = YearMonth(year: startYear, month: startMonth)
        let end   = YearMonth(year: endYear,   month: endMonth)

        guard start <= end else {
            errorMessage = "終了年月は開始年月より後に設定してください"
            return
        }
        guard monthlyAmount > 0 else {
            errorMessage = "積立額を入力してください"
            return
        }

        let entry = NISAEntry(
            type: selectedType,
            start: start,
            end: end,
            monthlyAmount: monthlyAmount
        )
        store.addEntry(entry)
        dismiss()
    }
}
