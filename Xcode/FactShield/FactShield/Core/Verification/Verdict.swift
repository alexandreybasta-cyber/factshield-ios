import Foundation

struct Verdict: Identifiable, Codable, Hashable {
    let id: UUID
    let claimId: UUID
    let verdictType: VerdictType
    let confidenceScore: Double  // 0.0 to 1.0
    let reasoning: String
    let sources: [Source]
    let timestamp: Date
    let elapsedSeconds: Int
    
    enum VerdictType: String, Codable, Hashable, CaseIterable {
        case `true` = "TRUE"
        case substantiallyTrue = "SUBSTANTIALLY TRUE"
        case misleading = "MISLEADING"
        case `false` = "FALSE"
        case unverifiable = "UNVERIFIABLE"
        
        var color: String {
            switch self {
            case .true: return "green"
            case .substantiallyTrue: return "yellow"
            case .misleading: return "orange"
            case .false: return "red"
            case .unverifiable: return "gray"
            }
        }
    }
}
