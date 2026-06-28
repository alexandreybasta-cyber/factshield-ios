import Foundation

struct FactCheckSession: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var transcript: String
    var claims: [Claim]
    var verdicts: [Verdict]
    var captureMode: CaptureMode
    var status: SessionStatus
    
    enum CaptureMode: String, Codable {
        case microphone
        case replayKit
    }
    
    enum SessionStatus: String, Codable {
        case active
        case completed
        case failed
        case cancelled
    }
    
    init(captureMode: CaptureMode = .microphone) {
        self.id = UUID()
        self.startedAt = Date()
        self.endedAt = nil
        self.transcript = ""
        self.claims = []
        self.verdicts = []
        self.captureMode = captureMode
        self.status = .active
    }
}

struct TranscriptSegment: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let timestamp: Date
    let speaker: String?
    let confidence: Double
    let isFinal: Bool
    
    init(text: String, timestamp: Date = Date(), speaker: String? = nil, confidence: Double = 1.0, isFinal: Bool = false) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.speaker = speaker
        self.confidence = confidence
        self.isFinal = isFinal
    }
}
