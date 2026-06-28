import Foundation
import OSLog

@Observable
final class EvidenceRetrievalService {
    static let shared = EvidenceRetrievalService()
    
    private let logger = Logger(subsystem: "com.factshield.verification", category: "EvidenceRetrieval")
    private let apiClient = QwenAPI.shared
    
    // Minimum sources required for cross-verification
    private let minSources = Constants.minSourcesForVerification
    private let maxSources = Constants.maxSourcesForVerification
    
    /// Retrieve evidence for a claim from multiple sources
    func retrieveEvidence(for claim: Claim) async throws -> [Evidence] {
        var allEvidence: [Evidence] = []
        
        // Parallel retrieval from multiple sources
        async let tavilyResults = searchTavily(query: claim.text, claimId: claim.id)
        async let googleFactCheck = searchGoogleFactCheck(query: claim.text, claimId: claim.id)
        async let newsSearch = searchNews(query: claim.text, claimId: claim.id)
        
        // Collect results, ignoring individual failures
        do {
            let tavily = try await tavilyResults
            allEvidence.append(contentsOf: tavily)
        } catch {
            logger.warning("Tavily search failed: \(error.localizedDescription)")
        }
        
        do {
            let google = try await googleFactCheck
            allEvidence.append(contentsOf: google)
        } catch {
            logger.warning("Google Fact Check search failed: \(error.localizedDescription)")
        }
        
        do {
            let news = try await newsSearch
            allEvidence.append(contentsOf: news)
        } catch {
            logger.warning("News search failed: \(error.localizedDescription)")
        }
        
        // Deduplicate by URL
        var seen = Set<String>()
        allEvidence = allEvidence.filter { evidence in
            let key = evidence.source.url
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        
        // Sort by weighted score (relevance + credibility)
        allEvidence.sort { $0.weightedScore > $1.weightedScore }
        
        // Take top N sources
        let topEvidence = Array(allEvidence.prefix(maxSources))
        
        logger.info("Retrieved \(topEvidence.count) evidence sources for claim: \(claim.text.prefix(50))")
        return topEvidence
    }
    
    // MARK: - Search Providers
    
    /// Search using Tavily API for web search results
    private func searchTavily(query: String, claimId: UUID) async throws -> [Evidence] {
        // Tavily API integration
        // In Phase 1, use Qwen to simulate evidence search via its training data
        // In production, replace with actual Tavily API call
        
        let searchPrompt = """
        You are a research assistant. For the following claim, provide 2-3 relevant evidence snippets 
        that either support or contradict it. For each piece of evidence, include:
        - A source name (real publication/organization name)
        - A URL (use a plausible URL for that source)
        - A snippet of text (2-3 sentences of factual information)
        - A relevance score (0.0 to 1.0)
        
        Claim: \(query)
        
        Return JSON with format:
        {"results": [{"sourceName": "...", "url": "...", "snippet": "...", "relevanceScore": 0.9}]}
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-plus",
            messages: [
                ["role": "system", "content": "You are a research assistant that finds evidence for fact-checking. Return only valid JSON."],
                ["role": "user", "content": searchPrompt]
            ],
            temperature: 0.3,
            responseFormat: ["type": "json_object"]
        )
        
        return try parseSearchResults(from: content, claimId: claimId, providerCredibility: 0.7)
    }
    
    /// Search Google Fact Check Tools API
    private func searchGoogleFactCheck(query: String, claimId: UUID) async throws -> [Evidence] {
        // Google Fact Check Tools API
        // Phase 1: Use Qwen to provide fact-check-like results
        // In production, replace with actual Google Fact Check API
        
        let factCheckPrompt = """
        You are a fact-check database. For the following claim, check if any major fact-checking 
        organizations have reviewed this or similar claims. Provide 1-2 results with:
        - The fact-checking organization name
        - Their URL
        - A snippet of their finding
        - How relevant this is to the claim (0.0 to 1.0)
        
        Claim: \(query)
        
        Return JSON:
        {"results": [{"sourceName": "...", "url": "...", "snippet": "...", "relevanceScore": 0.85}]}
        
        If no fact-checks exist for this claim, return: {"results": []}
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-plus",
            messages: [
                ["role": "system", "content": "You are a fact-check database lookup service. Return only valid JSON."],
                ["role": "user", "content": factCheckPrompt]
            ],
            temperature: 0.2,
            responseFormat: ["type": "json_object"]
        )
        
        return try parseSearchResults(from: content, claimId: claimId, providerCredibility: 0.9)
    }
    
    /// Search news sources
    private func searchNews(query: String, claimId: UUID) async throws -> [Evidence] {
        // News API integration
        // Phase 1: Use Qwen for news-like results
        // In production, replace with actual news API
        
        let newsPrompt = """
        You are a news archive search engine. For the following claim, find 1-2 relevant news 
        articles from reputable outlets. Provide:
        - The publication name
        - An article URL
        - A relevant snippet from the article
        - How relevant this article is to verifying the claim (0.0 to 1.0)
        
        Claim: \(query)
        
        Return JSON:
        {"results": [{"sourceName": "...", "url": "...", "snippet": "...", "relevanceScore": 0.8}]}
        """
        
        let content = try await apiClient.chatCompletion(
            model: "qwen-plus",
            messages: [
                ["role": "system", "content": "You are a news archive search service. Return only valid JSON."],
                ["role": "user", "content": newsPrompt]
            ],
            temperature: 0.3,
            responseFormat: ["type": "json_object"]
        )
        
        return try parseSearchResults(from: content, claimId: claimId, providerCredibility: 0.75)
    }
    
    // MARK: - Parsing
    
    private func parseSearchResults(from json: String, claimId: UUID, providerCredibility: Double) throws -> [Evidence] {
        struct SearchResponse: Codable {
            let results: [SearchResult]
            
            struct SearchResult: Codable {
                let sourceName: String
                let url: String
                let snippet: String
                let relevanceScore: Double
            }
        }
        
        let cleaned = cleanJSONString(json)
        guard let data = cleaned.data(using: .utf8) else {
            return []
        }
        
        do {
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            
            return decoded.results.map { result in
                let source = Source(
                    id: UUID(),
                    name: result.sourceName,
                    url: result.url,
                    credibilityScore: providerCredibility,
                    biasRating: nil,
                    snippet: result.snippet
                )
                
                return Evidence(
                    id: UUID(),
                    claimId: claimId,
                    source: source,
                    snippet: result.snippet,
                    relevanceScore: min(1.0, max(0.0, result.relevanceScore)),
                    credibilityScore: providerCredibility,
                    retrievedAt: Date()
                )
            }
        } catch {
            logger.error("Failed to parse search results: \(error.localizedDescription)")
            return []
        }
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
