import Foundation
import OSLog

/// Manages the rolling transcript buffer and provides access to transcript segments
@Observable
final class TranscriptManager {
    static let shared = TranscriptManager()
    
    private let logger = Logger(subsystem: "com.factshield.speech", category: "TranscriptManager")
    
    // All transcript segments from the current session
    private(set) var segments: [TranscriptSegment] = []
    
    // Full transcript text
    var fullTranscript: String {
        segments.map { $0.text }.joined(separator: " ")
    }
    
    // Recent transcript (last N seconds worth)
    func recentTranscript(seconds: TimeInterval = 30) -> String {
        let cutoff = Date().addingTimeInterval(-seconds)
        let recentSegments = segments.filter { $0.timestamp >= cutoff }
        return recentSegments.map { $0.text }.joined(separator: " ")
    }
    
    func addSegment(_ segment: TranscriptSegment) {
        segments.append(segment)
        trimOldSegments()
    }
    
    func addSegment(text: String, isFinal: Bool = false, confidence: Double = 1.0) {
        let segment = TranscriptSegment(
            text: text,
            timestamp: Date(),
            speaker: nil,
            confidence: confidence,
            isFinal: isFinal
        )
        addSegment(segment)
    }
    
    private func trimOldSegments() {
        // Keep max 5 minutes of transcript
        let cutoff = Date().addingTimeInterval(-300)
        segments = segments.filter { $0.timestamp >= cutoff }
    }
    
    func reset() {
        segments.removeAll()
        logger.info("Transcript manager reset")
    }
}
