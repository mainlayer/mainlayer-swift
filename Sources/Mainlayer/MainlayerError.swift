import Foundation

/// Errors that can be thrown by the Mainlayer SDK.
public enum MainlayerError: Error, LocalizedError, Sendable {
    /// The API returned an HTTP error with a status code and optional message.
    case httpError(statusCode: Int, message: String)
    /// The response body could not be decoded into the expected type.
    case decodingError(Error)
    /// The request body could not be encoded.
    case encodingError(Error)
    /// A network-level error occurred (e.g. no connectivity).
    case networkError(Error)
    /// The API key is missing or empty.
    case missingAPIKey
    /// A URL could not be constructed from the given components.
    case invalidURL(String)
    /// The server returned an unexpected or empty response.
    case unexpectedResponse

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let message):
            return "Mainlayer API error (HTTP \(statusCode)): \(message)"
        case .decodingError(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request body: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .missingAPIKey:
            return "A valid Mainlayer API key is required. Set it when initialising the client."
        case .invalidURL(let url):
            return "Could not construct a valid URL from: \(url)"
        case .unexpectedResponse:
            return "The server returned an unexpected or empty response."
        }
    }

    public var failureReason: String? {
        switch self {
        case .httpError(let statusCode, _):
            switch statusCode {
            case 400: return "Bad request — check the parameters you supplied."
            case 401: return "Unauthorised — your API key may be invalid or revoked."
            case 403: return "Forbidden — you do not have permission to perform this action."
            case 404: return "Not found — the requested resource does not exist."
            case 422: return "Unprocessable entity — the request payload failed validation."
            case 429: return "Too many requests — you have been rate-limited. Slow down and retry."
            case 500...: return "Server error — Mainlayer is experiencing issues. Try again later."
            default: return nil
            }
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Pass your API key to Mainlayer(apiKey:) during initialisation."
        case .httpError(401, _):
            return "Verify your API key at mainlayer.fr and create a new one if needed."
        case .httpError(429, _):
            return "Implement exponential back-off before retrying the request."
        default:
            return nil
        }
    }
}
