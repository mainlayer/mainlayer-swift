import Foundation

/// The main entry point for the Mainlayer Swift SDK.
///
/// `Mainlayer` is a Swift `actor`, making all API calls safe to use from concurrent
/// contexts without additional synchronisation. Every method performs one network
/// round-trip and returns a strongly-typed Swift value.
///
/// ## Quick start
///
/// ```swift
/// import Mainlayer
///
/// let client = Mainlayer(apiKey: "ml_live_...")
///
/// // Vendor profile
/// let vendor = try await client.getVendor()
/// print(vendor.name)
///
/// // Publish a resource
/// let resource = try await client.createResource(.init(
///     name: "Weather API",
///     description: "Real-time weather data",
///     endpoint: "https://weather.example.com/api",
///     priceUsd: 0.01
/// ))
///
/// // Pay for a resource
/// let payment = try await client.pay(.init(
///     resourceId: resource.id,
///     payerWallet: "agent_abc123",
///     amountUsdc: 0.01
/// ))
/// ```
public actor Mainlayer {

    // MARK: - Properties

    private let network: NetworkClient

    // MARK: - Initialisation

    /// Creates a new Mainlayer client.
    ///
    /// - Parameter apiKey: Your Mainlayer API key. Find or create one at mainlayer.fr.
    public init(apiKey: String) {
        self.network = NetworkClient(apiKey: apiKey)
    }

    /// Creates a new Mainlayer client with a custom base URL and URLSession (for testing).
    ///
    /// - Parameters:
    ///   - apiKey: Your Mainlayer API key.
    ///   - baseURL: Override the default `https://api.mainlayer.xyz` base URL.
    ///   - session: A custom `URLSessionProtocol` implementation (e.g. a mock for unit tests).
    public init(apiKey: String, baseURL: URL, session: URLSessionProtocol) {
        self.network = NetworkClient(baseURL: baseURL, apiKey: apiKey, session: session)
    }

    // MARK: - Vendor

    /// Fetches the authenticated vendor's profile.
    ///
    /// - Returns: A `VendorResponse` containing the vendor's name, email, and stats.
    /// - Throws: `MainlayerError` on network or API failure.
    public func getVendor() async throws -> VendorResponse {
        try await network.get("/vendor")
    }

    // MARK: - Resources

    /// Creates a new billable resource.
    ///
    /// - Parameter request: The resource definition including name, endpoint, and price.
    /// - Returns: The newly created `ResourceResponse` with its server-assigned `id`.
    /// - Throws: `MainlayerError` on network or API failure.
    public func createResource(_ request: CreateResourceRequest) async throws -> ResourceResponse {
        try await network.post("/resources", body: request)
    }

    /// Lists all resources owned by the authenticated vendor.
    ///
    /// - Returns: An array of `ResourceResponse` objects.
    /// - Throws: `MainlayerError` on network or API failure.
    public func listResources() async throws -> [ResourceResponse] {
        try await network.get("/resources")
    }

    // MARK: - Payments

    /// Processes a payment for a resource.
    ///
    /// - Parameter request: Payment details including resource ID, payer identity, and amount.
    /// - Returns: A `PaymentResponse` with the transaction ID and status.
    /// - Throws: `MainlayerError` on network or API failure.
    public func pay(_ request: PayRequest) async throws -> PaymentResponse {
        try await network.post("/pay", body: request)
    }

    // MARK: - Entitlements

    /// Checks whether a payer currently has access to a resource.
    ///
    /// - Parameters:
    ///   - resourceId: The resource to check.
    ///   - payerWallet: The payer identity to check (wallet address, agent ID, etc.).
    /// - Returns: An `EntitlementResponse` indicating whether access is granted.
    /// - Throws: `MainlayerError` on network or API failure.
    public func checkEntitlement(resourceId: String, payerWallet: String) async throws -> EntitlementResponse {
        let queryItems = [
            URLQueryItem(name: "resource_id", value: resourceId),
            URLQueryItem(name: "payer_wallet", value: payerWallet)
        ]
        return try await network.get("/entitlements/check", queryItems: queryItems)
    }

    // MARK: - Discovery

    /// Browses publicly listed resources on Mainlayer.
    ///
    /// - Parameters:
    ///   - query: An optional search string to filter results by name or description.
    ///   - limit: Maximum number of results to return. Defaults to 20, capped server-side.
    /// - Returns: An array of matching `ResourceResponse` objects.
    /// - Throws: `MainlayerError` on network or API failure.
    public func discover(query: String = "", limit: Int = 20) async throws -> [ResourceResponse] {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        return try await network.get("/discover", queryItems: queryItems)
    }

    // MARK: - Analytics

    /// Retrieves revenue analytics for the authenticated vendor.
    ///
    /// - Returns: A `RevenueResponse` with totals and per-resource breakdowns.
    /// - Throws: `MainlayerError` on network or API failure.
    public func getRevenue() async throws -> RevenueResponse {
        try await network.get("/analytics/revenue")
    }
}
