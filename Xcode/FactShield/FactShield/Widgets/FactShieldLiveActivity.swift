import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - FactCheckAttributes (Live Activity data model)
// Shared between main app target and widget extension target

struct FactCheckAttributes: ActivityAttributes {
    var captureMode: CaptureMode
    var sourceApp: String?
    var startedAt: Date
    
    public struct ContentState: Codable, Hashable {
        var status: VerificationStatus
        var verdict: VerdictType?
        var confidenceScore: Double
        var sourceCount: Int
        var topSources: [String]
        var reasoningSummary: String?
        var claimText: String?
        var elapsedSeconds: Int
        var updatedAt: Date
    }
    
    enum CaptureMode: String, Codable, Hashable {
        case microphone = "Microphone"
        case replayKit = "System Audio"
    }
    
    enum VerificationStatus: String, Codable, Hashable {
        case listening = "Listening..."
        case transcribing = "Transcribing..."
        case extracting = "Extracting claims..."
        case searching = "Searching evidence..."
        case verifying = "Cross-checking..."
        case complete = "Complete"
    }
    
    enum VerdictType: String, Codable, Hashable {
        case `true` = "TRUE"
        case substantiallyTrue = "SUBSTANTIALLY TRUE"
        case misleading = "MISLEADING"
        case `false` = "FALSE"
        case unverifiable = "UNVERIFIABLE"
    }
}
