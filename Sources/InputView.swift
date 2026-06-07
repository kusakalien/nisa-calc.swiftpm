import SwiftUI

struct InputView: View {
    @Environment(NISAStore.self) private var store
    @State private var showingAddSheet = false
    @State private var editingEntry: NISAEntry?

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
                                .contentShape(Rectangle())
                                .onTapGesture { editingEntry = entry }
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
                EntrySheet(mode: .add)
            }
            .sheet(item: $editingEntry) { entry in
                EntrySheet(mode: .edit(entry))
            }
        }
    }
}

// MARK: - EntryRow

private struct EntryRow: View {
    let entry: NISAEntry

    private var periodText: String {
        if entry.isSpot {
            return "\(entry.start.displayString) 購入"
        }
        switch entry.endMode {
        case .fixedDate(let end):
            return "\(entry.start.displayString) 〜 \(end.displayString)"
        case .untilLimitReached:
            return "\(entry.start.displayString) 〜 満額になるまで"
        }
    }

    private var amountLabel: String {
        let formatted = entry.amount.formatted(.currency(code: "JPY").precision(.fractionLength(0)))
        return entry.isSpot ? formatted : formatted + "/月"
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.type.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.type.rawValue)
                        .font(.subheadline.bold())
                    if entry.isSpot {
                        Text("スポット購入")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                Text(periodText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if entry.isSpot && !entry.memo.isEmpty {
                    Text(entry.memo)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text(amountLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EntrySheet

enum EntrySheetMode {
    case add
    case edit(NISAEntry)
}

private enum PurchaseMode: String, CaseIterable, Identifiable {
    case recurring = "積立"
    case spot      = "スポット購入"
    var id: String { rawValue }
}

private enum EndChoice: String, CaseIterable, Identifiable {
    case fixedDate  = "年月を指定"
    case untilLimit = "満額になるまで"
    var id: String { rawValue }
}

struct EntrySheet: View {
    @Environment(NISAStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: EntrySheetMode

    @State private var selectedType: NISAType = .tsumitate
    @State private var purchaseMode: PurchaseMode = .recurring
    @State private var endChoice: EndChoice = .fixedDate
    @State private var startYear  = 2024
    @State private var startMonth = 1
    @State private var endYear    = 2028
    @State private var endMonth   = 12
    @State private var amountText = "100000"
    @State private var memo       = ""
    @State private var errorMessage: String?

    private let years  = Array(2024...2060)
    private let months = Array(1...12)

    private var amount: Int { Int(amountText) ?? 0 }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 成長投資枠を選んだ場合のみスポット購入を選択可能
    private var isSpotMode: Bool {
        selectedType == .growth && purchaseMode == .spot
    }

    var body: some View {
        NavigationStack {
            Form {
                typeSection

                if isSpotMode {
                    spotSections
                } else {
                    recurringSections
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "積立プランを編集" : "積立プランを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "追加") { commit() }
                        .disabled(amount <= 0)
                }
            }
            .onAppear { loadInitialValues() }
            .onChange(of: selectedType) { _, newValue in
                if newValue == .tsumitate { purchaseMode = .recurring }
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
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

            if selectedType == .growth {
                Picker("購入方法", selection: $purchaseMode) {
                    ForEach(PurchaseMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    @ViewBuilder
    private var spotSections: some View {
        Section("購入年月") {
            yearMonthPicker(year: $startYear, month: $startMonth)
        }

        Section("購入金額") {
            amountField
            limitHint(monthly: false)
        }

        Section("メモ") {
            TextField("銘柄など (例: ○○株式会社)", text: $memo)
        }
    }

    @ViewBuilder
    private var recurringSections: some View {
        Section("開始年月") {
            yearMonthPicker(year: $startYear, month: $startMonth)
        }

        Section("終了年月") {
            Picker("終了の指定方法", selection: $endChoice) {
                ForEach(EndChoice.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            switch endChoice {
            case .fixedDate:
                yearMonthPicker(year: $endYear, month: $endMonth)
            case .untilLimit:
                Text("生涯非課税保有限度額(\(selectedType.totalLimit.manEnDisplay))に達するまで毎月積み立てます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("毎月の積立額") {
            amountField
            limitHint(monthly: true)
        }
    }

    private func yearMonthPicker(year: Binding<Int>, month: Binding<Int>) -> some View {
        HStack {
            Picker("年", selection: year) {
                ForEach(years, id: \.self) { Text("\($0)年") }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("月", selection: month) {
                ForEach(months, id: \.self) { Text("\($0)月") }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: 100)
        }
        .frame(height: 120)
    }

    private var amountField: some View {
        HStack {
            Text("¥")
                .foregroundStyle(.secondary)
            TextField("例: 100000", text: $amountText)
                .keyboardType(.numberPad)
        }
    }

    private func limitHint(monthly: Bool) -> some View {
        Group {
            if monthly {
                let m = selectedType.annualLimit / 12
                Text("月額上限の目安: \(m.formatted(.currency(code: "JPY").precision(.fractionLength(0))))")
            } else {
                Text("年間上限: \(selectedType.annualLimit.manEnDisplay) / 生涯上限: \(selectedType.totalLimit.manEnDisplay)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func loadInitialValues() {
        guard case .edit(let entry) = mode else { return }
        selectedType = entry.type
        purchaseMode = entry.isSpot ? .spot : .recurring
        startYear    = entry.start.year
        startMonth   = entry.start.month
        amountText   = "\(entry.amount)"
        memo         = entry.memo

        switch entry.endMode {
        case .fixedDate(let end):
            endChoice = .fixedDate
            endYear   = end.year
            endMonth  = end.month
        case .untilLimitReached:
            endChoice = .untilLimit
        }
    }

    private func commit() {
        guard amount > 0 else {
            errorMessage = "金額を入力してください"
            return
        }

        let start = YearMonth(year: startYear, month: startMonth)
        let isSpot = isSpotMode

        let endMode: EndMode
        if isSpot {
            endMode = .fixedDate(start)
        } else {
            switch endChoice {
            case .fixedDate:
                let end = YearMonth(year: endYear, month: endMonth)
                guard start <= end else {
                    errorMessage = "終了年月は開始年月より後に設定してください"
                    return
                }
                endMode = .fixedDate(end)
            case .untilLimit:
                endMode = .untilLimitReached
            }
        }

        let entryID: UUID = {
            if case .edit(let original) = mode { return original.id }
            return UUID()
        }()

        let entry = NISAEntry(
            id: entryID,
            type: selectedType,
            isSpot: isSpot,
            start: start,
            endMode: endMode,
            amount: amount,
            memo: isSpot ? memo : ""
        )

        switch mode {
        case .add:  store.addEntry(entry)
        case .edit: store.updateEntry(entry)
        }
        dismiss()
    }
}
