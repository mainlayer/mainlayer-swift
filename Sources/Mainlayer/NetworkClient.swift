import Foundation

/// Protocol that mirrors the subset of `URLSession` used by `NetworkClient`,
/// allowing test code to inject a mock session.
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// MARK: - NetworkClient

/// Low-level HTTP client responsible for building requests, injecting auth headers,
/// encoding JSON bodies, and decoding JSON responses.
actor NetworkClient {

    // MARK: - Properties

    private let baseURL: URL
    private let apiKey: String
    private let session: URLSessionProtocol
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialisation

    init(
        baseURL: URL = URL(string: "https://api.mainlayer.xyz")!,
        apiKey: String,
        session: URLSessionProtocol = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.keyEncodingStrategy = .useDefaultKeys
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .useDefaultKeys
        self.decoder = dec
    }

    // MARK: - Public request methods

    /// Performs a GET request and decodes the response body into `T`.
    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        let request = try buildRequest(method: "GET", path: path, queryItems: queryItems, body: nil as EmptyBody?)
        return try await perform(request)
    }

    /// Performs a POST request, encoding `body` as JSON, and decodes the response into `T`.
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let bodyData = try encode(body)
        let request = try buildRequest(method: "POST", path: path, queryItems: [], bodyData: bodyData)
        return try await perform(request)
    }

    // MARK: - Private helpers

    private struct EmptyBody: Encodable {}

    private func buildRequest<Body: Encodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Body?
    ) throws -> URLRequest {
        let bodyData: Data? = try body.map { try encode($0) }
        return try buildRequest(method: method, path: path, queryItems: queryItems, bodyData: bodyData)
    }

    private func buildRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        bodyData: Data?
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else {
            throw MainlayerError.missingAPIKey
        }

        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw MainlayerError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("mainlayer-swift/1.0.0", forHTTPHeaderField: "User-Agent")

        if let data = bodyData {
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            throw MainlayerError.encodingError(error)
        }
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as MainlayerError {
            throw error
        } catch {
            throw MainlayerError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MainlayerError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data, statusCode: httpResponse.statusCode)
            throw MainlayerError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw MainlayerError.decodingError(error)
        }
    }

    private func extractErrorMessage(from data: Data, statusCode: Int) -> String {
        if let envelope = try? decoder.decode(APIErrorResponse.self, from: data) {
            return envelope.bestMessage
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        return HTTPURLResponse.localizedString(forStatusCode: statusCode)
    }
}
