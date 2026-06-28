import Foundation
import OSLog

// MARK: - Search API Client
// Handles external search API integrations (Tavily, Google Fact Check Tools)
// Phase 1: Stubbed out. Phase 2: Full API integration.

/// Protocol defining a search provider interface
protocol SearchProvider {
    func search(query: String, maxResults: Int) async throws -> [SearchResult]
}

/// Generic search result from any provider
struct SearchResult: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let snippet: String
    let publishedDate: String?
    let score: Double
    let source: String
    
    init(title: String, url: String, snippet: String, publishedDate: String? = nil, score: Double, source: String) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.snippet = snippet
        self.publishedDate = publishedDate
        self.score = score
        self.source = source
    }
}

// MARK: - Tavily Search Provider

final class TavilySearchProvider: SearchProvider {
    private let logger = Logger(subsystem: "com.factshield.api", category: "TavilySearch")
    private let apiClient = APIClient.shared
    
    private var apiKey: String {
        ProcessInfo.processInfo.environment["TAVILY_API_KEY"] ?? 
        UserDefaults.standard.string(forKey: "tavily_api_key") ?? ""
    }
    
    func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        guard !apiKey.isEmpty else {
            logger.warning("Tavily API key not configured")
            return []
        }
        
        guard let url = URL(string: "https://api.tavily.com/search") else {
            throw APIError.invalidURL
        }
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "search_depth": "advanced",
            "include_answer": false,
            "max_results": maxResults
        ]
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        let headers: [String: String] = [
            "Content-Type": "application/json"
        ]
        
        let response = try await apiClient.requestJSON(
            url: url,
            method: "POST",
            headers: headers,
            body: bodyData
        )
        
        return parseTavilyResponse(response)
    }
    
    private func parseTavilyResponse(_ json: [String: Any]) -> [SearchResult] {
        guard let results = json["results"] as? [[String: Any]] else {
            return []
        }
        
        return results.compactMap { result in
            guard let title = result["title"] as? String,
                  let url = result["url"] as? String,
                  let content = result["content"] as? String else {
                return nil
            }
            
            let score = result["score"] as? Double ?? 0.5
            let publishedDate = result["published_date"] as? String
            
            return SearchResult(
                title: title,
                url: url,
                snippet: content,
                publishedDate: publishedDate,
                score: score,
                source: "Tavily"
            )
        }
    }
}

// MARK: - Google Fact Check Tools Provider

final class GoogleFactCheckProvider: SearchProvider {
    private let logger = Logger(subsystem: "com.factshield.api", category: "GoogleFactCheck")
    private let apiClient = APIClient.shared
    
    private var apiKey: String {
        ProcessInfo.processInfo.environment["GOOGLE_FACTCHECK_API_KEY"] ?? 
        UserDefaults.standard.string(forKey: "google_factcheck_api_key") ?? ""
    }
    
    func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        guard !apiKey.isEmpty else {
            logger.warning("Google Fact Check API key not configured")
            return []
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://factchecktools.googleapis.com/v1alpha1/claims:search?query=\(encodedQuery)&key=\(apiKey)&pageSize=\(maxResults)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        let response = try await apiClient.requestJSON(
            url: url,
            method: "GET",
            headers: [:]
        )
        
        return parseGoogleFactCheckResponse(response)
    }
    
    private func parseGoogleFactCheckResponse(_ json: [String: Any]) -> [SearchResult] {
        guard let claims = json["claims"] as? [[String: Any]] else {
            return []
        }
        
        return claims.compactMap { claim in
            guard let text = claim["text"] as? String,
                  let claimReview = (claim["claimReview"] as? [[String: Any]])?.first else {
                return nil
            }
            
            let url = claimReview["url"] as? String ?? ""
            let publisherName = (claimReview["publisher"] as? [String: Any])?["name"] as? String ?? "Unknown"
            let rating = claimReview["textualRating"] as? String ?? ""
            
            return SearchResult(
                title: text,
                url: url,
                snippet: "Rating: \(rating) — Reviewed by \(publisherName)",
                publishedDate: claimReview["reviewDate"] as? String,
                score: 0.9, // Fact-checks are highly relevant
                source: "Google Fact Check"
            )
        }
    }
}
