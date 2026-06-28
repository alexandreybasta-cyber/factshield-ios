import AVFoundation
import Speech
import OSLog

@Observable
final class AudioBufferProcessor {
    static let shared = AudioBufferProcessor()
    
    private let speechRecognizer = SpeechRecognitionService.shared
    private let logger = Logger(subsystem: "com.factshield.audio", category: "BufferProcessor")
    
    // Rolling buffer of recent audio (for speech recognition)
    private var accumulatedBuffers: [AVAudioPCMBuffer] = []
    private let maxBufferDuration: TimeInterval = 30.0  // Max 30 seconds of accumulated audio
    
    private var processedCount: Int = 0
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        accumulatedBuffers.append(buffer)
        trimOldBuffers()
        processedCount += 1
        
        // Log every 50th buffer to confirm pipe is connected
        if processedCount == 1 {
            logger.info("\u{2705} First audio buffer received by AudioBufferProcessor — pipe is connected")
        } else if processedCount % 50 == 0 {
            logger.info("AudioBufferProcessor: \(self.processedCount) buffers processed")
        }
        
        // Feed to speech recognizer
        speechRecognizer.processAudioBuffer(buffer)
    }
    
    private func trimOldBuffers() {
        var totalDuration: TimeInterval = 0
        for buffer in accumulatedBuffers.reversed() {
            totalDuration += Double(buffer.frameLength) / Double(buffer.format.sampleRate)
            if totalDuration > maxBufferDuration {
                break
            }
        }
        // Keep only recent buffers
        if accumulatedBuffers.count > 100 {
            accumulatedBuffers = Array(accumulatedBuffers.suffix(50))
        }
    }
    
    func reset() {
        accumulatedBuffers.removeAll()
    }
}
