import Foundation
import StoreKit
import Observation

/// StoreKit 2 を用いた買い切り課金の管理
@Observable
final class StoreManager {
    /// 「運用益シミュレーション」機能のプロダクトID
    /// App Store Connect で同じIDの非消耗型(Non-Consumable)商品を登録すること
    static let returnSimulationProductID = "com.kusakalien.nisacalc.returnsimulation"

    /// 取得済みの商品情報(価格表示などに利用)
    private(set) var product: Product?
    /// 運用益シミュレーションを購入済みか
    private(set) var isReturnSimulationUnlocked = false
    /// 購入・復元処理中か
    private(set) var isProcessing = false
    /// エラーメッセージ(UI表示用)
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshPurchasedStatus()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// 価格表示用の文字列(取得失敗時はnil)
    var displayPrice: String? { product?.displayPrice }

    // MARK: - Product loading

    @MainActor
    func loadProducts() async {
        errorMessage = nil
        do {
            let products = try await Product.products(for: [Self.returnSimulationProductID])
            product = products.first
            if product == nil {
                errorMessage = "商品情報を取得できませんでした。時間をおいて「再読み込み」をお試しください"
            }
        } catch {
            errorMessage = "商品情報の取得に失敗しました。時間をおいて「再読み込み」をお試しください"
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchase() async {
        guard let product else {
            errorMessage = "商品情報を読み込めませんでした。時間をおいて再度お試しください"
            return
        }
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isReturnSimulationUnlocked = true
                    await transaction.finish()
                } else {
                    errorMessage = "購入の検証に失敗しました"
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "購入が保留されています。承認後に反映されます"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入に失敗しました"
        }
    }

    // MARK: - Restore

    @MainActor
    func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await AppStore.sync()
            await refreshPurchasedStatus()
            if !isReturnSimulationUnlocked {
                errorMessage = "復元可能な購入が見つかりませんでした"
            }
        } catch {
            errorMessage = "購入の復元に失敗しました"
        }
    }

    // MARK: - Entitlement

    @MainActor
    func refreshPurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.returnSimulationProductID,
               transaction.revocationDate == nil {
                isReturnSimulationUnlocked = true
                return
            }
        }
        isReturnSimulationUnlocked = false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case .verified(let transaction) = result {
                    await self.refreshPurchasedStatus()
                    await transaction.finish()
                }
            }
        }
    }
}
