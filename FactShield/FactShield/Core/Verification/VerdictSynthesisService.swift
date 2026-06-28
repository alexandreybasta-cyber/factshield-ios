import Foundation
import OSLog

// MARK: - Synthesis Error

enum SynthesisError: Error, LocalizedError {
    case noContent
    case invalidJSON
    case invalidVerdictType(String)
    
    var errorDescription: String? {
        switch self {
        case .noContent: return "No content in API response"
        case .invalidJSON: return "Failed to parse verdict JSON"
        case .invalidVerdictType(let type): return "Invalid verdict type: \(type)"
        }
    }
}

// MARK: - Verdict Synthesis Service

@Observable
final class VerdictSynthesisService {
    static let shared = VerdictSynthesisService()
    
    private let apiClient = QwenAPI.shared
    private let logger = Logger(subsystem: "com.factshield.verification", category: "VerdictSynthesis")
    
    /// Synthesize a verdict from evidence using chain-of-thought reasoning
    func synthesizeVerdict(claim: Claim, evidence: [Evidence]) async throws -> Verdict {
        let startTime = Date()
        
        let evidenceText = evidence.enumerated().map { index, e in
            """
            Source \(index + 1): \(e.source.name) (Credibility: \(String(format: "%.2f", e.credibilityScore))/1.0, Bias: \(e.source.biasRating ?? "unknown"))
            Snippet: \(e.snippet)
            URL: \(e.source.url)
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        You are a professional fact-checker. Analyze the claim against the provided evidence and render a verdict.
        
        Claim: \(claim.text)
        
        Evidence:
        \(evidenceText)
        
        Instructions:
        1. First, think step by step about what the evidence says
        2. Compare the claim against each piece of evidence
        3. Consider source credibility and potential bias
        4. If evidence conflicts, explain which is more reliable and why
        5. Render one of these verdicts: TRUE, SUBSTANTIALLY TRUE, MISLEADING, FALSE, UNVERIFIABLE
        6. Provide a confidence score from 0.0 to 1.0
        7. Write a clear, concise reasoning summary (2-3 sentences)
        
        Return JSON with these fields:
        - "verdict": one of the five verdict types (exactly as written above)
        - "confidence": number between 0.0 and 1.0
        - "reasoning": string explaining the verdict
        - "sourceAnalysis": array of objects with "sourceName", "supportsClaim" (boolean), "credibility" (number)
        
        Return ONLY the JSON.
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-max",
            messages: [
                ["role": "system", "content": "You are an expert fact-checker. Be rigorous, non-biased, and transparent about uncertainty. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.2,
            responseFormat: ["type": "json_object"]
        )
        
        let verdict = try parseVerdict(from: content, claimId: claim.id, evidence: evidence, startTime: startTime)
        logger.info("Verdict synthesized: \(verdict.verdictType.rawValue) (confidence: \(String(format: "%.2f", verdict.confidenceScore)))")
        return verdict
    }
    
    /// Synthesize a verdict when no external evidence is available (using model knowledge only)
    func synthesizeVerdictWithoutEvidence(claim: Claim) async throws -> Verdict {
        let startTime = Date()
        
        let prompt = """
        You are a professional fact-checker. Analyze the following claim using your knowledge.
        
        Claim: \(claim.text)
        
        Instructions:
        1. Assess whether this claim is factually accurate based on your training data
        2. If you are not confident, mark it as UNVERIFIABLE
        3. Render one of these verdicts: TRUE, SUBSTANTIALLY TRUE, MISLEADING, FALSE, UNVERIFIABLE
        4. Provide a confidence score from 0.0 to 1.0
        5. Write a clear reasoning (2-3 sentences)
        6. Note: Without external evidence, confidence should generally be lower
        
        Return JSON:
        {
            "verdict": "...",
            "confidence": 0.0,
            "reasoning": "...",
            "sourceAnalysis": []
        }
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-max",
            messages: [
                ["role": "system", "content": "You are an expert fact-checker. Without external evidence, be extra cautious and transparent about uncertainty. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.2,
            responseFormat: ["type": "json_object"]
        )
        
        let verdict = try parseVerdict(from: content, claimId: claim.id, evidence: [], startTime: startTime)
        logger.info("Verdict (no evidence): \(verdict.verdictType.rawValue) (confidence: \(String(format: "%.2f", verdict.confidenceScore)))")
        return verdict
    }
    
    // MARK: - Private Parsing
    
    private func parseVerdict(from json: String, claimId: UUID, evidence: [Evidence], startTime: Date) throws -> Verdict {
        struct VerdictResponse: Codable {
            let verdict: String
            let confidence: Double
            let reasoning: String
            let sourceAnalysis: [SourceAnalysis]?
            
            struct SourceAnalysis: Codable {
                let sourceName: String
                let supportsClaim: Bool
                let credibility: Double
            }
        }
        
        let cleaned = cleanJSONString(json)
        guard let data = cleaned.data(using: .utf8) else {
            throw SynthesisError.invalidJSON
        }
        
        let decoded: VerdictResponse
        do {
            decoded = try JSONDecoder().decode(VerdictResponse.self, from: data)
        } catch {
            logger.error("Failed to decode verdict JSON: \(error.localizedDescription)")
            throw SynthesisError.invalidJSON
        }
        
        let verdictType = Verdict.VerdictType(rawValue: decoded.verdict.uppercased()) ?? .unverifiable
        let elapsed = Int(Date().timeIntervalSince(startTime))
        
        return Verdict(
            id: UUID(),
            claimId: claimId,
            verdictType: verdictType,
            confidenceScore: max(0, min(1, decoded.confidence)),
            reasoning: decoded.reasoning,
            sources: evidence.map { $0.source },
            timestamp: Date(),
            elapsedSeconds: elapsed
        )
    }
    
    /// Clean JSON string by removing markdown code fences
    private func cleanJSONString(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
