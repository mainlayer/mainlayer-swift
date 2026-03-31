/**
 VendorExample.swift
 Mainlayer Swift SDK

 Demonstrates how a vendor (API provider) uses Mainlayer to:
  1. Fetch their vendor profile and revenue stats.
  2. Publish a new billable resource.
  3. List all published resources.
  4. Poll revenue analytics.

 Run from the command line (requires Swift toolchain):
   swift run VendorExample
 */

import Foundation
import Mainlayer

// ---------------------------------------------------------------------------
// Configuration — replace with your real API key from mainlayer.fr
// ---------------------------------------------------------------------------
let vendorAPIKey = ProcessInfo.processInfo.environment["MAINLAYER_API_KEY"] ?? "ml_live_YOUR_KEY_HERE"

@main
struct VendorExample {
    static func main() async {
        let client = Mainlayer(apiKey: vendorAPIKey)

        do {
            // 1. Fetch vendor profile
            print("=== Vendor Profile ===")
            let vendor = try await client.getVendor()
            print("Name:     \(vendor.name)")
            print("Email:    \(vendor.email)")
            if let website = vendor.website { print("Website:  \(website)") }
            if let count = vendor.resourceCount { print("Resources: \(count)") }
            if let rev = vendor.revenue {
                print("Revenue:  $\(String(format: "%.2f", rev.totalUsd)) (\(rev.transactionCount) transactions)")
            }
            print()

            // 2. Publish a new resource
            print("=== Creating Resource ===")
            let newResource = try await client.createResource(.init(
                name: "Real-Time Weather API",
                description: "Hourly weather data for any city worldwide. Returns temperature, humidity, wind speed, and a 7-day forecast.",
                endpoint: "https://weather.yourapi.com/v1",
                priceUsd: 0.002,
                tags: ["weather", "data", "real-time"]
            ))
            print("Created resource: \(newResource.name)")
            print("Resource ID:      \(newResource.id)")
            print("Endpoint:         \(newResource.endpoint ?? "n/a")")
            print("Price:            $\(String(format: "%.4f", newResource.priceUsd ?? 0)) per request")
            print()

            // 3. List all resources
            print("=== All Resources ===")
            let resources = try await client.listResources()
            if resources.isEmpty {
                print("No resources published yet.")
            } else {
                for resource in resources {
                    let price = resource.priceUsd.map { String(format: "$%.4f", $0) } ?? "free"
                    let status = resource.active == true ? "active" : "inactive"
                    print("[\(status)] \(resource.name) — \(price) — \(resource.id)")
                }
            }
            print()

            // 4. Revenue analytics
            print("=== Revenue Analytics ===")
            let revenue = try await client.getRevenue()
            print("Total revenue:    $\(String(format: "%.2f", revenue.totalUsd))")
            print("Transactions:     \(revenue.transactionCount)")
            if let breakdown = revenue.byResource {
                print("By resource:")
                for (id, amount) in breakdown.sorted(by: { $0.value > $1.value }) {
                    print("  \(id): $\(String(format: "%.2f", amount))")
                }
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
