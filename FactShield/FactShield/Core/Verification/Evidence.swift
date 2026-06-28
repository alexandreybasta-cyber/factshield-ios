import Foundation

struct Evidence: Identifiable, Codable, Hashable {
    let id: UUID
    let claimId: UUID
    let source: Source
    let snippet: String
    let relevanceScore: Double
    let credibilityScore: Double
    let retrievedAt: Date
    
    var weightedScore: Double {
        relevanceScore * 0.6 + credibilityScore * 0.4
    }
}
