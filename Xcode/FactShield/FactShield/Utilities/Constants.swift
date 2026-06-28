import Foundation

enum Constants {
    // MARK: - App Group
    static let appGroupIdentifier = "group.com.factshield.shared"
    
    // MARK: - Bundle IDs
    static let mainBundleId = "com.factshield.app"
    static let broadcastBundleId = "com.factshield.app.broadcast"
    
    // MARK: - API
    static let qwenBaseURL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    
    // MARK: - Audio
    static let defaultSampleRate: Double = 16000.0
    static let defaultBufferSize: UInt32 = 1024
    static let maxRecordingDuration: TimeInterval = 300.0 // 5 minutes max
    
    // MARK: - Speech Recognition
    static let maxTranscriptWords = 2000
    static let recentTranscriptWords = 75 // ~30 seconds at normal speech rate
    
    // MARK: - Fact Checking Pipeline
    static let claimExtractionInterval: TimeInterval = 15.0
    static let minSourcesForVerification = 3
    static let maxSourcesForVerification = 5
    
    // MARK: - UserDefaults Keys
    static let isBroadcastingKey = "isBroadcasting"
    static let broadcastStartedAtKey = "broadcastStartedAt"
    static let lastSessionIdKey = "lastSessionId"
    
    // MARK: - Notification Names
    static let broadcastStartedNotification = Notification.Name("com.factshield.broadcastStarted")
    static let broadcastEndedNotification = Notification.Name("com.factshield.broadcastEnded")
}
