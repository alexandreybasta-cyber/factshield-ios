import AVFoundation
import OSLog

actor AudioSessionManager {
    static let shared = AudioSessionManager()
    private let logger = Logger(subsystem: "com.factshield.audio", category: "AudioSession")
    
    func configureForCapture() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,          // Enables AEC
            options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        logger.info("Audio session configured for voice chat mode (AEC enabled)")
    }
    
    func deactivate() throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
