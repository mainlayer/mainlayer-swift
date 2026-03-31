/**
 BuyerExample.swift
 Mainlayer Swift SDK

 Demonstrates how a buyer (AI agent or end user) uses Mainlayer to:
  1. Discover publicly available resources.
  2. Check whether access is already granted before paying.
  3. Pay for a resource.
  4. Verify the entitlement after payment.

 Run from the command line (requires Swift toolchain):
   MAINLAYER_API_KEY=ml_live_... AGENT_WALLET=agent_abc123 swift run BuyerExample
 */

import Foundation
import Mainlayer

// ---------------------------------------------------------------------------
// Configuration — replace with real values or set environment variables
// ---------------------------------------------------------------------------
let buyerAPIKey   = ProcessInfo.processInfo.environment["MAINLAYER_API_KEY"]  ?? "ml_live_YOUR_KEY_HERE"
let agentWalletId = ProcessInfo.processInfo.environment["AGENT_WALLET"]       ?? "agent_YOUR_WALLET_ID"

@main
struct BuyerExample {
    static func main() async {
        let client = Mainlayer(apiKey: buyerAPIKey)

        do {
            // 1. Discover resources
            print("=== Discovering Resources ===")
            let resources = try await client.discover(query: "weather", limit: 10)

            if resources.isEmpty {
                print("No resources found. Check your API key and try again.")
                return
            }

            print("Found \(resources.count) resource(s):\n")
            for (index, resource) in resources.enumerated() {
                let price = resource.priceUsd.map { String(format: "$%.4f", $0) } ?? "free"
                print("[\(index + 1)] \(resource.name)")
                print("     ID:       \(resource.id)")
                print("     Price:    \(price)")
                print("     Tags:     \(resource.tags?.joined(separator: ", ") ?? "none")")
                print()
            }

            // Use the first result for the rest of the example
            guard let target = resources.first else { return }
            print("Targeting: \(target.name) (\(target.id))\n")

            // 2. Check existing entitlement before paying
            print("=== Checking Existing Entitlement ===")
            let existingAccess = try await client.checkEntitlement(
                resourceId: target.id,
                payerWallet: agentWalletId
            )

            if existingAccess.hasAccess {
                print("You already have access to '\(target.name)'.")
                if let expiry = existingAccess.expiresAt {
                    print("Access expires: \(expiry)")
                }
                return
            } else {
                print("No existing access found. Proceeding to payment.\n")
            }

            // 3. Pay for the resource
            print("=== Processing Payment ===")
            let amount = target.priceUsd ?? 0.01
            let payment = try await client.pay(.init(
                resourceId: target.id,
                payerWallet: agentWalletId,
                amountUsdc: amount
            ))

            print("Transaction ID: \(payment.transactionId)")
            print("Status:         \(payment.status)")
            print("Amount paid:    $\(String(format: "%.4f", payment.amountUsdc))")
            print("Processed at:   \(payment.processedAt)")
            print()

            guard payment.status == "success" else {
                print("Payment did not succeed. Status: \(payment.status)")
                return
            }

            // 4. Verify entitlement after payment
            print("=== Verifying Entitlement ===")
            let newAccess = try await client.checkEntitlement(
                resourceId: target.id,
                payerWallet: agentWalletId
            )

            if newAccess.hasAccess {
                print("Access confirmed for '\(target.name)'.")
                if let expiry = newAccess.expiresAt {
                    print("Expires: \(expiry)")
                }
                print("\nYou can now call the resource at: \(target.endpoint ?? "see resource details")")
            } else {
                print("Warning: payment succeeded but entitlement not yet reflected. Retry shortly.")
            }

        } catch let error as MainlayerError {
            print("Mainlayer error: \(error.localizedDescription)")
            if let reason = error.failureReason { print("Reason: \(reason)") }
            if let suggestion = error.recoverySuggestion { print("Suggestion: \(suggestion)") }
        } catch {
            print("Unexpected error: \(error)")
        }
    }
}
