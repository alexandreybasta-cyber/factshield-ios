import Foundation
import OSLog

// MARK: - API Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case invalidJSON
    case decodingError(String)
    case timeout
    case noAPIKey
    case rateLimited(retryAfter: Int?)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        case .invalidJSON: return "Invalid JSON response"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .timeout: return "Request timed out"
        case .noAPIKey: return "API key is not configured"
        case .rateLimited(let retry): return "Rate limited. Retry after \(retry ?? 60)s"
        }
    }
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let logger = Logger(subsystem: "com.factshield.api", category: "APIClient")
    
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request
    
    func request<T: Decodable>(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        var lastError: Error = APIError.invalidResponse
        
        for attempt in 0..<maxRetries {
            do {
                let result = try await performRequest(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body,
                    responseType: responseType
                )
                return result
            } catch let error as APIError {
                lastError = error
                
                switch error {
                case .rateLimited(let retryAfter):
                    let delay = TimeInterval(retryAfter ?? Int(baseRetryDelay * pow(2, Double(attempt))))
                    logger.warning("Rate limited. Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                case .httpError(let code, _) where code >= 500:
                    let delay = baseRetryDelay * pow(2, Double(attempt))
                    logger.warning("Server error \(code). Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                case .timeout:
                    let delay = baseRetryDelay * pow(2, Double(attempt))
                    logger.warning("Timeout. Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                default:
                    throw error
                }
            } catch {
                lastError = error
                let delay = baseRetryDelay * pow(2, Double(attempt))
                if attempt < maxRetries - 1 {
                    logger.warning("Request failed: \(error.localizedDescription). Retrying after \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError
    }
    
    // MARK: - Raw JSON Request (returns [String: Any])
    
    func requestJSON(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> [String: Any] {
        var lastError: Error = APIError.invalidResponse
        
        for attempt in 0..<maxRetries {
            do {
                let result = try await performJSONRequest(
                    url: url,
                    method: method,
                    headers: headers,
                    body: body
                )
                return result
            } catch let error as APIError {
                lastError = error
                
                switch error {
                case .rateLimited(let retryAfter):
                    let delay = TimeInterval(retryAfter ?? Int(baseRetryDelay * pow(2, Double(attempt))))
                    logger.warning("Rate limited. Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                case .httpError(let code, _) where code >= 500:
                    let delay = baseRetryDelay * pow(2, Double(attempt))
                    logger.warning("Server error \(code). Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                case .timeout:
                    let delay = baseRetryDelay * pow(2, Double(attempt))
                    logger.warning("Timeout. Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                default:
                    throw error
                }
            } catch {
                lastError = error
                let delay = baseRetryDelay * pow(2, Double(attempt))
                if attempt < maxRetries - 1 {
                    logger.warning("Request failed: \(error.localizedDescription). Retrying after \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError
    }
    
    // MARK: - Private Helpers
    
    private func performRequest<T: Decodable>(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        try validateHTTPResponse(httpResponse, data: data)
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
    
    private func performJSONRequest(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        try validateHTTPResponse(httpResponse, data: data)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidJSON
        }
        
        return json
    }
    
    private func validateHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(response.statusCode, errorBody)
        }
    }
}
