import Foundation
import OSLog

// MARK: - Qwen API Response Models

struct QwenChatResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let role: String
        let content: String
    }
    
    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct QwenChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let responseFormat: ResponseFormat?
    
    struct ChatMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ResponseFormat: Codable {
        let type: String
    }
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

// MARK: - Qwen API Client

final class QwenAPI: Sendable {
    static let shared = QwenAPI()
    
    private let baseURL = Constants.qwenBaseURL
    private let logger = Logger(subsystem: "com.factshield.api", category: "QwenAPI")
    private let apiClient = APIClient.shared
    
    // API key — in production, use Keychain
    private var apiKey: String {
        // Load from environment or UserDefaults; in production use Keychain
        if let envKey = ProcessInfo.processInfo.environment["QWEN_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        return UserDefaults.standard.string(forKey: "qwen_api_key") ?? ""
    }
    
    // MARK: - Chat Completion
    
    /// Send a chat completion request to Qwen API
    /// - Parameters:
    ///   - model: Model name (e.g., "qwen-plus", "qwen-max")
    ///   - messages: Array of message dictionaries with "role" and "content"
    ///   - temperature: Sampling temperature (0.0-1.0)
    ///   - maxTokens: Maximum tokens in response
    ///   - responseFormat: Optional response format (e.g., ["type": "json_object"])
    /// - Returns: The content string from the first choice in the API response
    func chatCompletion(
        model: String = "qwen-plus",
        messages: [[String: String]],
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        responseFormat: [String: String]? = nil
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        // Build request body
        let chatMessages = messages.compactMap { msg -> QwenChatRequest.ChatMessage? in
            guard let role = msg["role"], let content = msg["content"] else { return nil }
            return QwenChatRequest.ChatMessage(role: role, content: content)
        }
        
        let requestBody = QwenChatRequest(
            model: model,
            messages: chatMessages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: responseFormat.map { QwenChatRequest.ResponseFormat(type: $0["type"] ?? "text") }
        )
        
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)
        
        let headers: [String: String] = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        logger.info("Sending request to Qwen API: model=\(model), messages=\(messages.count)")
        
        let response = try await apiClient.request(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData,
            responseType: QwenChatResponse.self
        )
        
        guard let content = response.choices.first?.message.content else {
            logger.error("No content in Qwen response")
            throw APIError.invalidJSON
        }
        
        if let usage = response.usage {
            logger.info("Qwen API usage - prompt: \(usage.promptTokens ?? 0), completion: \(usage.completionTokens ?? 0), total: \(usage.totalTokens ?? 0)")
        }
        
        return content
    }
    
    // MARK: - Convenience: Chat completion returning raw JSON dict
    
    /// Chat completion that returns the full raw JSON response as dictionary
    func chatCompletionRaw(
        model: String = "qwen-plus",
        messages: [[String: String]],
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        responseFormat: [String: String]? = nil
    ) async throws -> [String: Any] {
        guard !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        if let responseFormat {
            body["response_format"] = responseFormat
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let headers: [String: String] = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        let response = try await apiClient.requestJSON(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )
        
        return response
    }
}
