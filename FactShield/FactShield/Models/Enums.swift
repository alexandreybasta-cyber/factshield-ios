import Foundation

// MARK: - App-wide Enums

enum AppTab: String, CaseIterable {
    case home
    case history
    case settings
}

enum AudioQuality: String, Codable {
    case low
    case medium
    case high
    
    var sampleRate: Double {
        switch self {
        case .low: return 16000.0
        case .medium: return 44100.0
        case .high: return 48000.0
        }
    }
}

enum FactShieldError: Error, LocalizedError {
    case audioSessionFailed(String)
    case speechRecognitionUnavailable
    case speechRecognitionDenied
    case networkError(String)
    case apiKeyMissing
    case claimExtractionFailed(String)
    case verdictSynthesisFailed(String)
    case liveActivityFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .audioSessionFailed(let msg): return "Audio session error: \(msg)"
        case .speechRecognitionUnavailable: return "Speech recognition is not available on this device"
        case .speechRecognitionDenied: return "Speech recognition permission was denied"
        case .networkError(let msg): return "Network error: \(msg)"
        case .apiKeyMissing: return "API key is not configured"
        case .claimExtractionFailed(let msg): return "Claim extraction failed: \(msg)"
        case .verdictSynthesisFailed(let msg): return "Verdict synthesis failed: \(msg)"
        case .liveActivityFailed(let msg): return "Live Activity error: \(msg)"
        }
    }
}
