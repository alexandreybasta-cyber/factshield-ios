import OSLog

/// Centralized logging wrapper using OSLog
enum AppLogger {
    static let audio = Logger(subsystem: "com.factshield.audio", category: "AudioCapture")
    static let audioSession = Logger(subsystem: "com.factshield.audio", category: "AudioSession")
    static let bufferProcessor = Logger(subsystem: "com.factshield.audio", category: "BufferProcessor")
    static let speech = Logger(subsystem: "com.factshield.speech", category: "SpeechRecognition")
    static let claims = Logger(subsystem: "com.factshield.claims", category: "ClaimExtraction")
    static let verification = Logger(subsystem: "com.factshield.verification", category: "EvidenceRetrieval")
    static let verdict = Logger(subsystem: "com.factshield.verification", category: "VerdictSynthesis")
    static let activity = Logger(subsystem: "com.factshield.activity", category: "ActivityManager")
    static let coordinator = Logger(subsystem: "com.factshield.core", category: "FactCheckCoordinator")
    static let api = Logger(subsystem: "com.factshield.api", category: "QwenAPI")
    static let broadcast = Logger(subsystem: "com.factshield.broadcast", category: "SampleHandler")
    static let general = Logger(subsystem: "com.factshield.app", category: "General")
}
