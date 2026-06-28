import ReplayKit
import OSLog

class SampleHandler: RPBroadcastSampleHandler {
    private let logger = Logger(subsystem: "com.factshield.broadcast", category: "SampleHandler")
    
    // Shared app group for passing data to the main app
    private let appGroup = "group.com.factshield.shared"
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        logger.info("Broadcast started")
        
        // Notify the main app that broadcast has started
        if let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(true, forKey: "isBroadcasting")
            defaults.set(Date(), forKey: "broadcastStartedAt")
        }
    }
    
    override func broadcastPaused() {
        logger.info("Broadcast paused")
    }
    
    override func broadcastResumed() {
        logger.info("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        logger.info("Broadcast finished")
        
        if let defaults = UserDefaults(suiteName: appGroup) {
            defaults.set(false, forKey: "isBroadcasting")
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // We don't need video
            break
            
        case .audioApp:
            // This is the system audio from the app being recorded
            // Convert to PCM and send to the main app via app group
            processAudioSampleBuffer(sampleBuffer)
            
        case .audioMic:
            // This is the microphone audio
            // We can combine or use this as fallback
            processAudioSampleBuffer(sampleBuffer)
            
        @unknown default:
            break
        }
    }
    
    private func processAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard let pointer = dataPointer, length > 0 else { return }
        
        // Write to shared app group directory
        let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        let audioFileURL = sharedContainer?.appendingPathComponent("broadcast_audio.raw")
        
        // Append audio data to file
        if let fileURL = audioFileURL {
            let data = Data(bytes: pointer, count: length)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
