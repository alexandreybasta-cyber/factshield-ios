import Foundation

struct Source: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let url: String
    let credibilityScore: Double  // 0.0 to 1.0
    let biasRating: String?       // "left", "center", "right"
    let snippet: String
}
