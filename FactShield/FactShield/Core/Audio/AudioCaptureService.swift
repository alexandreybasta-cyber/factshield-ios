import AVFoundation
import OSLog

@Observable
final class AudioCaptureService {
    static let shared = AudioCaptureService()
    
    private let engine = AVAudioEngine()
    private let logger = Logger(subsystem: "com.factshield.audio", category: "AudioCapture")
    
    var isListening: Bool = false
    var currentBuffer: AVAudioPCMBuffer?
    
    // Callback for when new audio is captured
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    private let bufferQueue = DispatchQueue(label: "com.factshield.audio.buffer", qos: .userInteractive)
    
    func startListening() {
        guard !isListening else { return }
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on the input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.bufferQueue.async {
                self?.onAudioBuffer?(buffer)
            }
        }
        
        engine.prepare()
        do {
            try engine.start()
            isListening = true
            logger.info("Audio capture started with format: \(recordingFormat)")
        } catch {
            logger.error("Failed to start audio engine: \(error)")
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        logger.info("Audio capture stopped")
    }
}
