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
    
    func processBuffer(_ buffer: AVAudioPCMBuffer) {
        accumulatedBuffers.append(buffer)
        trimOldBuffers()
        
        // Feed to speech recognizer in chunks
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
