import Foundation

// MARK: - Vendor

/// The vendor profile returned by `GET /vendor`.
public struct VendorResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for the vendor.
    public let id: String
    /// Display name of the vendor.
    public let name: String
    /// Contact email address.
    public let email: String
    /// Optional website URL.
    public let website: String?
    /// ISO 8601 timestamp of when the vendor account was created.
    public let createdAt: String
    /// Total number of resources published by this vendor.
    public let resourceCount: Int?
    /// Aggregate revenue statistics for this vendor.
    public let revenue: RevenueSummary?

    enum CodingKeys: String, CodingKey {
        case id, name, email, website
        case createdAt = "created_at"
        case resourceCount = "resource_count"
        case revenue
    }
}

// MARK: - Resource

/// A resource (API, dataset, model, tool, etc.) listed on Mainlayer.
public struct ResourceResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for the resource.
    public let id: String
    /// Human-readable title.
    public let name: String
    /// Long-form description of the resource.
    public let description: String
    /// Endpoint or access URL for the resource.
    public let endpoint: String?
    /// Pricing in USD (display only — billing is handled server-side).
    public let priceUsd: Double?
    /// Identifier of the vendor who owns this resource.
    public let vendorId: String
    /// ISO 8601 creation timestamp.
    public let createdAt: String
    /// Arbitrary metadata tags.
    public let tags: [String]?
    /// Whether this resource is currently active and purchasable.
    public let active: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, endpoint, tags, active
        case priceUsd = "price_usd"
        case vendorId = "vendor_id"
        case createdAt = "created_at"
    }
}

/// Request body for `POST /resources`.
public struct CreateResourceRequest: Codable, Sendable {
    /// Human-readable title for the resource.
    public let name: String
    /// Long-form description.
    public let description: String
    /// Public endpoint URL where the resource can be accessed.
    public let endpoint: String
    /// Price in USD.
    public let priceUsd: Double
    /// Optional metadata tags for discoverability.
    public let tags: [String]?

    public init(
        name: String,
        description: String,
        endpoint: String,
        priceUsd: Double,
        tags: [String]? = nil
    ) {
        self.name = name
        self.description = description
        self.endpoint = endpoint
        self.priceUsd = priceUsd
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case name, description, endpoint, tags
        case priceUsd = "price_usd"
    }
}

// MARK: - Payment

/// Request body for `POST /pay`.
public struct PayRequest: Codable, Sendable {
    /// The resource to purchase access to.
    public let resourceId: String
    /// Identifier for the payer (wallet address, agent ID, etc.).
    public let payerWallet: String
    /// Amount in USD to charge.
    public let amountUsdc: Double

    public init(resourceId: String, payerWallet: String, amountUsdc: Double) {
        self.resourceId = resourceId
        self.payerWallet = payerWallet
        self.amountUsdc = amountUsdc
    }

    enum CodingKeys: String, CodingKey {
        case resourceId = "resource_id"
        case payerWallet = "payer_wallet"
        case amountUsdc = "amount_usdc"
    }
}

/// Response from `POST /pay`.
public struct PaymentResponse: Codable, Sendable {
    /// Unique transaction identifier.
    public let transactionId: String
    /// Current status of the payment (e.g. `"success"`, `"pending"`, `"failed"`).
    public let status: String
    /// Resource ID that was purchased.
    public let resourceId: String
    /// Payer identifier.
    public let payerWallet: String
    /// Amount charged in USD.
    public let amountUsdc: Double
    /// ISO 8601 timestamp of when the payment was processed.
    public let processedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case transactionId = "transaction_id"
        case resourceId = "resource_id"
        case payerWallet = "payer_wallet"
        case amountUsdc = "amount_usdc"
        case processedAt = "processed_at"
    }
}

// MARK: - Entitlements

/// Response from `GET /entitlements/check`.
public struct EntitlementResponse: Codable, Sendable {
    /// Whether the payer currently has access to the resource.
    public let hasAccess: Bool
    /// Resource that was checked.
    public let resourceId: String
    /// Payer that was checked.
    public let payerWallet: String
    /// ISO 8601 timestamp of when access expires, if applicable.
    public let expiresAt: String?
    /// The most recent transaction granting access, if any.
    public let grantedByTransaction: String?

    enum CodingKeys: String, CodingKey {
        case hasAccess = "has_access"
        case resourceId = "resource_id"
        case payerWallet = "payer_wallet"
        case expiresAt = "expires_at"
        case grantedByTransaction = "granted_by_transaction"
    }
}

// MARK: - Revenue

/// Aggregate revenue statistics returned by `GET /analytics/revenue`.
public struct RevenueResponse: Codable, Sendable {
    /// Total revenue earned, in USD.
    public let totalUsd: Double
    /// Number of successful transactions counted in this report.
    public let transactionCount: Int
    /// Revenue broken down by resource ID.
    public let byResource: [String: Double]?
    /// ISO 8601 start of the reporting period.
    public let periodStart: String?
    /// ISO 8601 end of the reporting period.
    public let periodEnd: String?

    enum CodingKeys: String, CodingKey {
        case totalUsd = "total_usd"
        case transactionCount = "transaction_count"
        case byResource = "by_resource"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }
}

/// Condensed revenue summary embedded in `VendorResponse`.
public struct RevenueSummary: Codable, Sendable {
    /// Total lifetime revenue in USD.
    public let totalUsd: Double
    /// Total number of successful transactions.
    public let transactionCount: Int

    enum CodingKeys: String, CodingKey {
        case totalUsd = "total_usd"
        case transactionCount = "transaction_count"
    }
}

// MARK: - API Error envelope

/// Error envelope returned by the Mainlayer API on failure.
struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
    let detail: String?

    /// Returns the most descriptive error message available.
    var bestMessage: String {
        error ?? message ?? detail ?? "Unknown error"
    }
}
