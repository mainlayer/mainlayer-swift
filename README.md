# Mainlayer Swift SDK

Swift SDK for [Mainlayer](https://mainlayer.fr) — payment infrastructure for AI agents.

Mainlayer lets you monetise any API, model, or data resource and collect revenue from agents or users with a single API call. This SDK wraps the REST API in idiomatic Swift: typed models, `async`/`await`, and full `Sendable` conformance.

## Requirements

| | Minimum |
|---|---|
| Swift | 5.9 |
| macOS | 13 |
| iOS | 16 |
| Xcode | 15 |

## Installation

### Swift Package Manager (recommended)

Add the dependency to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mainlayer/mainlayer-swift.git", from: "1.0.0")
]
```

Then add `"Mainlayer"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["Mainlayer"]
)
```

### Xcode

1. **File > Add Package Dependencies…**
2. Enter `https://github.com/mainlayer/mainlayer-swift`
3. Select **Up to Next Major Version** from `1.0.0`

## Quick Start

```swift
import Mainlayer

let client = Mainlayer(apiKey: "ml_live_...")

// Publish a resource
let resource = try await client.createResource(.init(
    name: "Weather API",
    description: "Real-time weather data for any city",
    endpoint: "https://weather.example.com/v1",
    priceUsd: 0.002,
    tags: ["weather", "real-time"]
))
print("Published: \(resource.id)")

// A buyer discovers and pays for your resource
let payment = try await client.pay(.init(
    resourceId: resource.id,
    payerWallet: "agent_abc123",
    amountUsdc: resource.priceUsd!
))
print("Transaction: \(payment.transactionId) — \(payment.status)")

// Verify entitlement before serving the resource
let access = try await client.checkEntitlement(
    resourceId: resource.id,
    payerWallet: "agent_abc123"
)
if access.hasAccess {
    // serve the resource
}
```

## API Reference

### Initialisation

```swift
// Production
let client = Mainlayer(apiKey: "ml_live_...")

// Custom base URL (e.g. staging)
let client = Mainlayer(
    apiKey: "ml_test_...",
    baseURL: URL(string: "https://staging.api.mainlayer.xyz")!,
    session: URLSession.shared
)
```

Get your API key at [mainlayer.fr](https://mainlayer.fr).

---

### Vendor

#### `getVendor() -> VendorResponse`

Fetch the authenticated vendor's profile, resource count, and lifetime revenue summary.

```swift
let vendor = try await client.getVendor()
print(vendor.name)           // "Acme AI"
print(vendor.revenue?.totalUsd ?? 0)  // 42.0
```

---

### Resources

#### `createResource(_ request: CreateResourceRequest) -> ResourceResponse`

Publish a new billable resource.

```swift
let resource = try await client.createResource(.init(
    name: "Finance API",
    description: "Real-time stock prices",
    endpoint: "https://finance.example.com/api",
    priceUsd: 0.005,
    tags: ["finance", "stocks"]
))
```

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | `String` | yes | Display name |
| `description` | `String` | yes | Long-form description |
| `endpoint` | `String` | yes | Access URL |
| `priceUsd` | `Double` | yes | Price per access in USD |
| `tags` | `[String]?` | no | Discovery tags |

#### `listResources() -> [ResourceResponse]`

List all resources owned by the authenticated vendor.

```swift
let resources = try await client.listResources()
for r in resources {
    print("\(r.name) — $\(r.priceUsd ?? 0)")
}
```

---

### Payments

#### `pay(_ request: PayRequest) -> PaymentResponse`

Process a payment for a resource.

```swift
let payment = try await client.pay(.init(
    resourceId: "res_abc123",
    payerWallet: "agent_xyz",
    amountUsdc: 0.005
))
// payment.status == "success"
// payment.transactionId == "txn_..."
```

| Field | Type | Description |
|---|---|---|
| `resourceId` | `String` | Resource to pay for |
| `payerWallet` | `String` | Payer identity (agent ID, wallet address, etc.) |
| `amountUsdc` | `Double` | Amount in USD |

---

### Entitlements

#### `checkEntitlement(resourceId:payerWallet:) -> EntitlementResponse`

Check whether a payer currently has access to a resource.

```swift
let check = try await client.checkEntitlement(
    resourceId: "res_abc123",
    payerWallet: "agent_xyz"
)
if check.hasAccess {
    // serve the resource
}
```

---

### Discovery

#### `discover(query:limit:) -> [ResourceResponse]`

Browse publicly listed resources. Optionally filter by search query.

```swift
let results = try await client.discover(query: "weather", limit: 10)
```

| Parameter | Default | Description |
|---|---|---|
| `query` | `""` | Full-text search string |
| `limit` | `20` | Max results to return |

---

### Analytics

#### `getRevenue() -> RevenueResponse`

Retrieve aggregate revenue statistics for the authenticated vendor.

```swift
let revenue = try await client.getRevenue()
print("Total: $\(revenue.totalUsd)")
print("Transactions: \(revenue.transactionCount)")
```

---

## Error Handling

All methods throw `MainlayerError`:

```swift
do {
    let vendor = try await client.getVendor()
} catch let error as MainlayerError {
    switch error {
    case .httpError(let code, let message):
        print("HTTP \(code): \(message)")
    case .networkError(let underlying):
        print("Network failure: \(underlying)")
    case .decodingError(let underlying):
        print("Decoding failed: \(underlying)")
    case .missingAPIKey:
        print("Set your API key at mainlayer.fr")
    case .encodingError, .invalidURL, .unexpectedResponse:
        print(error.localizedDescription)
    }
}
```

`MainlayerError` conforms to `LocalizedError` and provides `errorDescription`, `failureReason`, and `recoverySuggestion` for all cases.

---

## SwiftUI Integration

See `Examples/iOSIntegration.swift` for a complete SwiftUI marketplace view with:

- Searchable resource catalogue
- Single-tap purchase flow
- Real-time payment status
- Entitlement badge after purchase

## Testing

The SDK ships with a `URLSessionProtocol` that makes it easy to inject a mock session in tests:

```swift
final class MockSession: URLSessionProtocol, @unchecked Sendable {
    var stubbedData = Data()
    var stubbedStatusCode = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubbedData, response)
    }
}

// In your test:
let session = MockSession()
session.stubbedData = vendorJSON
let client = Mainlayer(
    apiKey: "ml_test_key",
    baseURL: URL(string: "https://api.mainlayer.xyz")!,
    session: session
)
let vendor = try await client.getVendor()
```

Run the full test suite:

```bash
swift test
```

## Examples

| File | Description |
|---|---|
| `Examples/VendorExample.swift` | Create and list resources, view revenue |
| `Examples/BuyerExample.swift` | Discover, pay, and verify entitlements |
| `Examples/iOSIntegration.swift` | Complete SwiftUI marketplace view |

## Contributing

Pull requests are welcome. Please ensure `swift test` passes and `swiftlint` reports no violations before submitting.

## Support

- Documentation: [mainlayer.fr](https://mainlayer.fr)
- Issues: [github.com/mainlayer/mainlayer-swift/issues](https://github.com/mainlayer/mainlayer-swift/issues)

## License

MIT
