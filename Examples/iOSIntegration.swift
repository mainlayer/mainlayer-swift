/**
 iOSIntegration.swift
 Mainlayer Swift SDK

 A complete SwiftUI example that:
  - Shows a browsable catalogue of resources from Mainlayer.
  - Lets the user pay for a resource with a single tap.
  - Displays real-time payment status.
  - Confirms access with an entitlement check.

 Integrate into your iOS app target (iOS 16+):
   1. Add the Mainlayer package via SPM.
   2. Drop this view into your scene hierarchy.
   3. Set your API key in the environment before launch.
 */

import SwiftUI
import Mainlayer

// MARK: - View Model

@MainActor
final class MarketplaceViewModel: ObservableObject {
    // MARK: Published state
    @Published var resources: [ResourceResponse] = []
    @Published var purchasedResourceIds: Set<String> = []
    @Published var paymentInProgress: String? = nil   // resource ID being purchased
    @Published var errorMessage: String? = nil
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false

    // MARK: Private
    private let client: Mainlayer

    init(apiKey: String) {
        self.client = Mainlayer(apiKey: apiKey)
    }

    // MARK: - Fetch

    func loadResources() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            resources = try await client.discover(query: searchQuery, limit: 20)
        } catch let error as MainlayerError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchase(resource: ResourceResponse, payerWallet: String) async {
        guard paymentInProgress == nil else { return }
        paymentInProgress = resource.id
        errorMessage = nil
        defer { paymentInProgress = nil }

        do {
            let payment = try await client.pay(.init(
                resourceId: resource.id,
                payerWallet: payerWallet,
                amountUsdc: resource.priceUsd ?? 0.01
            ))

            if payment.status == "success" {
                purchasedResourceIds.insert(resource.id)
            } else {
                errorMessage = "Payment returned status: \(payment.status)"
            }
        } catch let error as MainlayerError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entitlement check

    func checkAccess(resourceId: String, payerWallet: String) async -> Bool {
        do {
            let result = try await client.checkEntitlement(
                resourceId: resourceId,
                payerWallet: payerWallet
            )
            if result.hasAccess {
                purchasedResourceIds.insert(resourceId)
            }
            return result.hasAccess
        } catch {
            return false
        }
    }
}

// MARK: - Root View

/// Drop this view into your app's `WindowGroup` or `NavigationStack`.
struct MainlayerMarketplaceView: View {
    @StateObject private var viewModel: MarketplaceViewModel
    private let payerWallet: String

    init(apiKey: String, payerWallet: String) {
        _viewModel = StateObject(
            wrappedValue: MarketplaceViewModel(apiKey: apiKey)
        )
        self.payerWallet = payerWallet
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.resources.isEmpty {
                    ProgressView("Loading resources…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.resources.isEmpty {
                    ContentUnavailableView(
                        "No Resources Found",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search query.")
                    )
                } else {
                    resourceList
                }
            }
            .navigationTitle("Mainlayer")
            .searchable(text: $viewModel.searchQuery, prompt: "Search resources…")
            .onSubmit(of: .search) {
                Task { await viewModel.loadResources() }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.loadResources()
        }
    }

    // MARK: - Subviews

    private var resourceList: some View {
        List(viewModel.resources) { resource in
            ResourceRow(
                resource: resource,
                isPurchased: viewModel.purchasedResourceIds.contains(resource.id),
                isProcessing: viewModel.paymentInProgress == resource.id
            ) {
                Task {
                    await viewModel.purchase(resource: resource, payerWallet: payerWallet)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.loadResources()
        }
    }
}

// MARK: - Resource Row

private struct ResourceRow: View {
    let resource: ResourceResponse
    let isPurchased: Bool
    let isProcessing: Bool
    let onPurchase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resource.name)
                        .font(.headline)
                    if let tags = resource.tags, !tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
                priceView
            }

            Text(resource.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            purchaseButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var priceView: some View {
        if let price = resource.priceUsd {
            Text(String(format: "$%.4f", price))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if isPurchased {
            Label("Access Granted", systemImage: "checkmark.seal.fill")
                .font(.footnote.bold())
                .foregroundStyle(.green)
        } else {
            Button(action: onPurchase) {
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Processing…")
                    }
                } else {
                    Text("Buy Access")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isProcessing)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    MainlayerMarketplaceView(
        apiKey: "ml_preview_key",
        payerWallet: "preview_wallet_123"
    )
}
#endif
