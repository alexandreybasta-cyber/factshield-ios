import Foundation

struct Claim: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let timestamp: Date
    let speaker: String?
    let checkWorthiness: CheckWorthiness
    let status: ClaimStatus
    
    enum CheckWorthiness: String, Codable, Hashable {
        case high      // Factual claim with clear truth value
        case medium    // Somewhat verifiable
        case low       // Opinion, vague, or trivial
    }
    
    enum ClaimStatus: String, Codable, Hashable {
        case pending
        case extracting
        case searching
        case verifying
        case complete
        case failed
    }
}

extension Claim {
    static let empty = Claim(
        id: UUID(),
        text: "",
        timestamp: Date(),
        speaker: nil,
        checkWorthiness: .low,
        status: .pending
    )
}
