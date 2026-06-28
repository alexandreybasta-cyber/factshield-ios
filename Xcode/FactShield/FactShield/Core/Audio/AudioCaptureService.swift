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
    private var bufferCount: Int = 0
    private var monitorTask: Task<Void, Never>?
    
    func startListening() {
        guard !isListening else { return }
        
        bufferCount = 0
        
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Validate format before proceeding
        guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
            logger.error("Invalid input format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount). Audio session may not be active.")
            return
        }
        
        // 1. Prepare engine BEFORE installing tap
        engine.prepare()
        
        // 2. Install tap with larger buffer size for reliable delivery
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            self.bufferQueue.async {
                self.bufferCount += 1
                self.currentBuffer = buffer
                self.onAudioBuffer?(buffer)
            }
        }
        
        // 3. Start the engine
        do {
            try engine.start()
            isListening = true
            logger.info("Audio capture started — format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch, bufferSize: 4096")
        } catch {
            logger.error("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            return
        }
        
        // 4. Monitor buffer flow — warn if zero buffers after 1 second
        monitorTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            guard let self = self, self.isListening else { return }
            
            let count = self.bufferCount
            if count == 0 {
                let session = AVAudioSession.sharedInstance()
                let route = session.currentRoute
                let inputs = route.inputs.map { "\($0.portName) (\($0.portType.rawValue))" }
                self.logger.warning("⚠️ ZERO audio buffers received after 1s — audio may not be flowing!")
                self.logger.warning("  Session active: \(session.isOtherAudioPlaying), category: \(session.category.rawValue)")
                self.logger.warning("  Input route: \(inputs)")
                self.logger.warning("  Engine running: \(self.engine.isRunning), inputNode format: \(self.engine.inputNode.outputFormat(forBus: 0))")
            } else {
                self.logger.info("Audio buffer monitor: \(count) buffers received in first 1s ✓")
            }
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        monitorTask?.cancel()
        monitorTask = nil
        
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        
        logger.info("Audio capture stopped — total buffers received: \(self.bufferCount)")
        bufferCount = 0
    }
}
