import XCTest
@testable import Mainlayer

// MARK: - Mock URLSession

/// Captures the URLRequest and returns a pre-configured stub response.
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var stubbedData: Data = Data()
    var stubbedStatusCode: Int = 200
    var capturedRequest: URLRequest?
    var shouldThrowNetworkError: Bool = false

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequest = request

        if shouldThrowNetworkError {
            throw URLError(.notConnectedToInternet)
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubbedData, response)
    }
}

// MARK: - Helpers

private func makeClient(session: MockURLSession) -> Mainlayer {
    Mainlayer(
        apiKey: "ml_test_key",
        baseURL: URL(string: "https://api.mainlayer.xyz")!,
        session: session
    )
}

private func encode<T: Encodable>(_ value: T) -> Data {
    try! JSONEncoder().encode(value)
}

// Fixture factories
private func vendorJSON() -> Data {
    """
    {
        "id": "vendor_001",
        "name": "Acme AI",
        "email": "hello@acme.ai",
        "website": "https://acme.ai",
        "created_at": "2024-01-01T00:00:00Z",
        "resource_count": 3,
        "revenue": { "total_usd": 42.0, "transaction_count": 7 }
    }
    """.data(using: .utf8)!
}

private func resourceJSON(id: String = "res_001") -> Data {
    """
    {
        "id": "\(id)",
        "name": "Weather API",
        "description": "Real-time weather data",
        "endpoint": "https://weather.example.com",
        "price_usd": 0.01,
        "vendor_id": "vendor_001",
        "created_at": "2024-01-01T00:00:00Z",
        "tags": ["weather", "data"],
        "active": true
    }
    """.data(using: .utf8)!
}

private func resourceListJSON() -> Data {
    """
    [
        {
            "id": "res_001",
            "name": "Weather API",
            "description": "Real-time weather data",
            "endpoint": "https://weather.example.com",
            "price_usd": 0.01,
            "vendor_id": "vendor_001",
            "created_at": "2024-01-01T00:00:00Z",
            "tags": ["weather"],
            "active": true
        },
        {
            "id": "res_002",
            "name": "Finance API",
            "description": "Stock price data",
            "endpoint": "https://finance.example.com",
            "price_usd": 0.05,
            "vendor_id": "vendor_001",
            "created_at": "2024-01-02T00:00:00Z",
            "tags": ["finance"],
            "active": true
        }
    ]
    """.data(using: .utf8)!
}

private func paymentJSON() -> Data {
    """
    {
        "transaction_id": "txn_abc123",
        "status": "success",
        "resource_id": "res_001",
        "payer_wallet": "agent_xyz",
        "amount_usdc": 0.01,
        "processed_at": "2024-01-01T12:00:00Z"
    }
    """.data(using: .utf8)!
}

private func entitlementJSON(hasAccess: Bool = true) -> Data {
    """
    {
        "has_access": \(hasAccess),
        "resource_id": "res_001",
        "payer_wallet": "agent_xyz",
        "expires_at": "2025-01-01T00:00:00Z",
        "granted_by_transaction": "txn_abc123"
    }
    """.data(using: .utf8)!
}

private func revenueJSON() -> Data {
    """
    {
        "total_usd": 123.45,
        "transaction_count": 42,
        "by_resource": { "res_001": 100.0, "res_002": 23.45 },
        "period_start": "2024-01-01T00:00:00Z",
        "period_end": "2024-12-31T23:59:59Z"
    }
    """.data(using: .utf8)!
}

private func apiErrorJSON(message: String = "Resource not found") -> Data {
    "{\"error\": \"\(message)\"}".data(using: .utf8)!
}

// MARK: - Test Suite

final class MainlayerTests: XCTestCase {

    // MARK: - Vendor tests

    func testGetVendorReturnsCorrectId() async throws {
        let session = MockURLSession()
        session.stubbedData = vendorJSON()
        let client = makeClient(session: session)

        let vendor = try await client.getVendor()

        XCTAssertEqual(vendor.id, "vendor_001")
    }

    func testGetVendorReturnsCorrectName() async throws {
        let session = MockURLSession()
        session.stubbedData = vendorJSON()
        let client = makeClient(session: session)

        let vendor = try await client.getVendor()

        XCTAssertEqual(vendor.name, "Acme AI")
    }

    func testGetVendorReturnsRevenueSummary() async throws {
        let session = MockURLSession()
        session.stubbedData = vendorJSON()
        let client = makeClient(session: session)

        let vendor = try await client.getVendor()

        XCTAssertEqual(vendor.revenue?.totalUsd, 42.0)
        XCTAssertEqual(vendor.revenue?.transactionCount, 7)
    }

    func testGetVendorUsesCorrectHTTPMethod() async throws {
        let session = MockURLSession()
        session.stubbedData = vendorJSON()
        let client = makeClient(session: session)

        _ = try await client.getVendor()

        XCTAssertEqual(session.capturedRequest?.httpMethod, "GET")
    }

    func testGetVendorSendsAuthHeader() async throws {
        let session = MockURLSession()
        session.stubbedData = vendorJSON()
        let client = makeClient(session: session)

        _ = try await client.getVendor()

        let authHeader = session.capturedRequest?.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer ml_test_key")
    }

    // MARK: - Resource tests

    func testCreateResourceReturnsCorrectId() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceJSON()
        let client = makeClient(session: session)

        let resource = try await client.createResource(.init(
            name: "Weather API",
            description: "Real-time weather data",
            endpoint: "https://weather.example.com",
            priceUsd: 0.01
        ))

        XCTAssertEqual(resource.id, "res_001")
    }

    func testCreateResourceUsesPostMethod() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceJSON()
        let client = makeClient(session: session)

        _ = try await client.createResource(.init(
            name: "Test",
            description: "Test resource",
            endpoint: "https://test.example.com",
            priceUsd: 1.0
        ))

        XCTAssertEqual(session.capturedRequest?.httpMethod, "POST")
    }

    func testCreateResourceEncodesBodyAsJSON() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceJSON()
        let client = makeClient(session: session)

        _ = try await client.createResource(.init(
            name: "Weather API",
            description: "Real-time weather data",
            endpoint: "https://weather.example.com",
            priceUsd: 0.01,
            tags: ["weather"]
        ))

        let bodyData = session.capturedRequest?.httpBody
        XCTAssertNotNil(bodyData)
        let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: bodyData!)
        XCTAssertNotNil(decoded["name"])
    }

    func testListResourcesReturnsAllItems() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceListJSON()
        let client = makeClient(session: session)

        let resources = try await client.listResources()

        XCTAssertEqual(resources.count, 2)
    }

    func testListResourcesDecodesFirstItem() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceListJSON()
        let client = makeClient(session: session)

        let resources = try await client.listResources()

        XCTAssertEqual(resources[0].name, "Weather API")
        XCTAssertEqual(resources[0].priceUsd, 0.01)
    }

    // MARK: - Payment tests

    func testPayReturnsTransactionId() async throws {
        let session = MockURLSession()
        session.stubbedData = paymentJSON()
        let client = makeClient(session: session)

        let payment = try await client.pay(.init(
            resourceId: "res_001",
            payerWallet: "agent_xyz",
            amountUsdc: 0.01
        ))

        XCTAssertEqual(payment.transactionId, "txn_abc123")
    }

    func testPayReturnsSuccessStatus() async throws {
        let session = MockURLSession()
        session.stubbedData = paymentJSON()
        let client = makeClient(session: session)

        let payment = try await client.pay(.init(
            resourceId: "res_001",
            payerWallet: "agent_xyz",
            amountUsdc: 0.01
        ))

        XCTAssertEqual(payment.status, "success")
    }

    func testPayUsesPostMethod() async throws {
        let session = MockURLSession()
        session.stubbedData = paymentJSON()
        let client = makeClient(session: session)

        _ = try await client.pay(.init(
            resourceId: "res_001",
            payerWallet: "agent_xyz",
            amountUsdc: 0.01
        ))

        XCTAssertEqual(session.capturedRequest?.httpMethod, "POST")
    }

    // MARK: - Entitlement tests

    func testCheckEntitlementGrantedReturnsTrue() async throws {
        let session = MockURLSession()
        session.stubbedData = entitlementJSON(hasAccess: true)
        let client = makeClient(session: session)

        let result = try await client.checkEntitlement(
            resourceId: "res_001",
            payerWallet: "agent_xyz"
        )

        XCTAssertTrue(result.hasAccess)
    }

    func testCheckEntitlementDeniedReturnsFalse() async throws {
        let session = MockURLSession()
        session.stubbedData = entitlementJSON(hasAccess: false)
        let client = makeClient(session: session)

        let result = try await client.checkEntitlement(
            resourceId: "res_001",
            payerWallet: "agent_xyz"
        )

        XCTAssertFalse(result.hasAccess)
    }

    func testCheckEntitlementIncludesQueryParams() async throws {
        let session = MockURLSession()
        session.stubbedData = entitlementJSON()
        let client = makeClient(session: session)

        _ = try await client.checkEntitlement(
            resourceId: "res_001",
            payerWallet: "agent_xyz"
        )

        let urlString = session.capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("resource_id=res_001"))
        XCTAssertTrue(urlString.contains("payer_wallet=agent_xyz"))
    }

    // MARK: - Discovery tests

    func testDiscoverReturnsResources() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceListJSON()
        let client = makeClient(session: session)

        let results = try await client.discover()

        XCTAssertEqual(results.count, 2)
    }

    func testDiscoverWithQueryIncludesQParam() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceListJSON()
        let client = makeClient(session: session)

        _ = try await client.discover(query: "weather")

        let urlString = session.capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("q=weather"))
    }

    func testDiscoverWithLimitIncludesLimitParam() async throws {
        let session = MockURLSession()
        session.stubbedData = resourceListJSON()
        let client = makeClient(session: session)

        _ = try await client.discover(limit: 5)

        let urlString = session.capturedRequest?.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("limit=5"))
    }

    // MARK: - Revenue tests

    func testGetRevenueReturnsTotalUsd() async throws {
        let session = MockURLSession()
        session.stubbedData = revenueJSON()
        let client = makeClient(session: session)

        let revenue = try await client.getRevenue()

        XCTAssertEqual(revenue.totalUsd, 123.45, accuracy: 0.001)
    }

    func testGetRevenueReturnsTransactionCount() async throws {
        let session = MockURLSession()
        session.stubbedData = revenueJSON()
        let client = makeClient(session: session)

        let revenue = try await client.getRevenue()

        XCTAssertEqual(revenue.transactionCount, 42)
    }

    func testGetRevenueReturnsPerResourceBreakdown() async throws {
        let session = MockURLSession()
        session.stubbedData = revenueJSON()
        let client = makeClient(session: session)

        let revenue = try await client.getRevenue()

        XCTAssertEqual(revenue.byResource?["res_001"], 100.0)
    }

    // MARK: - Error handling tests

    func testHTTPErrorThrowsMainlayerError() async throws {
        let session = MockURLSession()
        session.stubbedStatusCode = 404
        session.stubbedData = apiErrorJSON(message: "Resource not found")
        let client = makeClient(session: session)

        do {
            _ = try await client.getVendor()
            XCTFail("Expected an error to be thrown")
        } catch let error as MainlayerError {
            if case .httpError(let code, let message) = error {
                XCTAssertEqual(code, 404)
                XCTAssertEqual(message, "Resource not found")
            } else {
                XCTFail("Expected MainlayerError.httpError, got \(error)")
            }
        }
    }

    func testUnauthorisedThrows401Error() async throws {
        let session = MockURLSession()
        session.stubbedStatusCode = 401
        session.stubbedData = apiErrorJSON(message: "Unauthorised")
        let client = makeClient(session: session)

        do {
            _ = try await client.getVendor()
            XCTFail("Expected an error to be thrown")
        } catch let error as MainlayerError {
            if case .httpError(let code, _) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("Expected httpError")
            }
        }
    }

    func testNetworkErrorWrappedCorrectly() async throws {
        let session = MockURLSession()
        session.shouldThrowNetworkError = true
        let client = makeClient(session: session)

        do {
            _ = try await client.getVendor()
            XCTFail("Expected an error to be thrown")
        } catch let error as MainlayerError {
            if case .networkError = error {
                // Pass
            } else {
                XCTFail("Expected MainlayerError.networkError, got \(error)")
            }
        }
    }

    func testInvalidJSONThrowsDecodingError() async throws {
        let session = MockURLSession()
        session.stubbedData = "not json".data(using: .utf8)!
        let client = makeClient(session: session)

        do {
            _ = try await client.getVendor()
            XCTFail("Expected an error to be thrown")
        } catch let error as MainlayerError {
            if case .decodingError = error {
                // Pass
            } else {
                XCTFail("Expected MainlayerError.decodingError, got \(error)")
            }
        }
    }

    func testMissingAPIKeyThrowsError() async throws {
        let client = Mainlayer(
            apiKey: "",
            baseURL: URL(string: "https://api.mainlayer.xyz")!,
            session: MockURLSession()
        )

        do {
            _ = try await client.getVendor()
            XCTFail("Expected missingAPIKey error")
        } catch let error as MainlayerError {
            if case .missingAPIKey = error {
                // Pass
            } else {
                XCTFail("Expected MainlayerError.missingAPIKey, got \(error)")
            }
        }
    }

    // MARK: - Error description tests

    func testHTTPErrorHasLocalizedDescription() {
        let error = MainlayerError.httpError(statusCode: 429, message: "Rate limited")
        XCTAssertTrue(error.localizedDescription.contains("429"))
        XCTAssertTrue(error.localizedDescription.contains("Rate limited"))
    }

    func testMissingAPIKeyHasLocalizedDescription() {
        let error = MainlayerError.missingAPIKey
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testInvalidURLHasLocalizedDescription() {
        let error = MainlayerError.invalidURL("/bad path")
        XCTAssertTrue(error.localizedDescription.contains("/bad path"))
    }
}

// MARK: - AnyCodable helper (used in request body assertions)

private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let n = try? container.decode(Double.self) { value = n }
        else if let b = try? container.decode(Bool.self) { value = b }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}
