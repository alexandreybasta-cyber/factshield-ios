import Foundation
import OSLog

@Observable
final class ClaimExtractionService {
    static let shared = ClaimExtractionService()
    
    private let apiClient = QwenAPI.shared
    private let logger = Logger(subsystem: "com.factshield.claims", category: "ClaimExtraction")
    
    // Extracted claims
    var claims: [Claim] = []
    var isExtracting: Bool = false
    
    // MARK: - Claim Extraction
    
    /// Extract verifiable claims from a transcript chunk
    func extractClaims(from transcript: String) async throws -> [Claim] {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isExtracting = true
        defer { isExtracting = false }
        
        let prompt = """
        You are a fact-checking assistant. Analyze the following transcript and extract all verifiable factual claims.
        
        Rules:
        - Only extract claims that can be objectively verified (statistics, dates, names, events, scientific facts)
        - Skip opinions, predictions about the future, and trivial statements
        - For each claim, rate its check-worthiness: "high" (important factual claim), "medium" (somewhat verifiable), "low" (opinion or vague)
        - Return a JSON object with a "claims" array of objects with "text" and "checkWorthiness" fields
        
        Transcript:
        \(transcript)
        
        Return ONLY the JSON object, no additional text. Example format:
        {"claims": [{"text": "The Earth is 4.5 billion years old", "checkWorthiness": "high"}]}
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-plus",
            messages: [
                ["role": "system", "content": "You are a fact-checking claim extraction assistant. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.1,
            responseFormat: ["type": "json_object"]
        )
        
        let extracted = try parseClaims(from: content)
        claims.append(contentsOf: extracted)
        logger.info("Extracted \(extracted.count) claims from transcript")
        return extracted
    }
    
    /// Filter claims to only high/medium check-worthiness
    func filterCheckWorthy(_ claims: [Claim]) -> [Claim] {
        claims.filter { $0.checkWorthiness != .low }
    }
    
    /// Reset all tracked claims
    func reset() {
        claims.removeAll()
    }
    
    // MARK: - Private Parsing
    
    private func parseClaims(from json: String) throws -> [Claim] {
        struct ClaimResponse: Codable {
            let claims: [ClaimItem]
            
            struct ClaimItem: Codable {
                let text: String
                let checkWorthiness: String
            }
        }
        
        // Try to parse the JSON, handling potential markdown code fences
        let cleanedJSON = cleanJSONString(json)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            logger.error("Failed to convert JSON string to data")
            throw FactShieldError.claimExtractionFailed("Invalid JSON encoding")
        }
        
        do {
            let decoded = try JSONDecoder().decode(ClaimResponse.self, from: data)
            
            return decoded.claims.map { item in
                Claim(
                    id: UUID(),
                    text: item.text,
                    timestamp: Date(),
                    speaker: nil,
                    checkWorthiness: Claim.CheckWorthiness(rawValue: item.checkWorthiness) ?? .medium,
                    status: .pending
                )
            }
        } catch {
            logger.error("Failed to decode claims JSON: \(error.localizedDescription)")
            
            // Attempt fallback: try parsing as a plain array
            return try parseClaimsArray(from: data)
        }
    }
    
    /// Fallback parser that handles the case where API returns a bare array
    private func parseClaimsArray(from data: Data) throws -> [Claim] {
        struct ClaimItem: Codable {
            let text: String
            let checkWorthiness: String
        }
        
        do {
            let items = try JSONDecoder().decode([ClaimItem].self, from: data)
            return items.map { item in
                Claim(
                    id: UUID(),
                    text: item.text,
                    timestamp: Date(),
                    speaker: nil,
                    checkWorthiness: Claim.CheckWorthiness(rawValue: item.checkWorthiness) ?? .medium,
                    status: .pending
                )
            }
        } catch {
            logger.error("Fallback array parsing also failed: \(error.localizedDescription)")
            throw FactShieldError.claimExtractionFailed("Could not parse API response as claims")
        }
    }
    
    /// Clean JSON string by removing markdown code fences and trimming whitespace
    private func cleanJSONString(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code fences if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
