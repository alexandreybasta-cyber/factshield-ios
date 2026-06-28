import AVFoundation
import OSLog

enum AudioSessionError: Error, CustomStringConvertible {
    case microphonePermissionDenied
    case categoryConfigurationFailed(Error)
    case activationFailed(Error)
    
    var description: String {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission denied — user must enable in Settings"
        case .categoryConfigurationFailed(let error):
            return "Audio session category configuration failed: \(error.localizedDescription)"
        case .activationFailed(let error):
            return "Audio session activation failed: \(error.localizedDescription)"
        }
    }
}

actor AudioSessionManager {
    static let shared = AudioSessionManager()
    private let logger = Logger(subsystem: "com.factshield.audio", category: "AudioSession")
    
    /// Configures and activates the audio session for microphone capture.
    /// Includes a post-activation delay to allow iOS to complete audio routing.
    func configureForCapture() async throws {
        let session = AVAudioSession.sharedInstance()
        
        // 1. Verify microphone permission is not denied
        let permission = session.recordPermission
        logger.info("Current record permission: \(String(describing: permission.rawValue))")
        
        guard permission != .denied else {
            logger.error("Microphone permission denied — cannot capture audio")
            throw AudioSessionError.microphonePermissionDenied
        }
        
        // If undetermined, request permission (blocks until user responds)
        if permission == .undetermined {
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                logger.error("User denied microphone permission")
                throw AudioSessionError.microphonePermissionDenied
            }
            logger.info("Microphone permission granted by user")
        }
        
        // 2. Configure audio session category
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers]
            )
            logger.info("Audio session category set: playAndRecord, mode: measurement")
        } catch {
            logger.error("Failed to set audio session category: \(error)")
            throw AudioSessionError.categoryConfigurationFailed(error)
        }
        
        // 3. Activate the session explicitly
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("Audio session activated successfully")
        } catch {
            logger.error("Failed to activate audio session: \(error)")
            throw AudioSessionError.activationFailed(error)
        }
        
        // 4. Brief delay to let iOS complete audio routing setup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // 5. Log final state for debugging
        let route = session.currentRoute
        let inputPorts = route.inputs.map { "\($0.portName) (\($0.portType.rawValue))" }
        logger.info("Audio routing complete. Input ports: \(inputPorts)")
        logger.info("Sample rate: \(session.sampleRate), IO buffer duration: \(session.ioBufferDuration)")
    }
    
    func deactivate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("Audio session deactivated")
    }
}
