import Speech
import AVFoundation
import OSLog

@Observable
final class SpeechRecognitionService {
    static let shared = SpeechRecognitionService()
    
    private let logger = Logger(subsystem: "com.factshield.speech", category: "SpeechRecognition")
    
    // Current transcript
    var currentTranscript: String = ""
    var isRecognizing: Bool = false
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    
    // Rolling transcript buffer (max ~2000 words)
    private var transcriptBuffer: [String] = []
    private let maxTranscriptWords = 2000
    
    // Buffer audio during recognition restarts so no frames are lost
    private var pendingBuffers: [AVAudioPCMBuffer] = []
    private var isRestarting: Bool = false
    
    // Serialization queue for thread-safe access to request/buffers
    private let recognitionQueue = DispatchQueue(label: "com.factshield.speech.recognition", qos: .userInteractive)
    
    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            switch status {
            case .authorized:
                self?.logger.info("Speech recognition authorized")
            case .denied, .restricted, .notDetermined:
                self?.logger.warning("Speech recognition not authorized: \(String(describing: status))")
            @unknown default:
                break
            }
        }
    }
    
    func startRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            logger.error("Speech recognizer not available")
            return
        }
        
        recognitionQueue.async { [weak self] in
            self?._startRecognitionOnQueue(speechRecognizer: speechRecognizer)
        }
    }
    
    private func _startRecognitionOnQueue(speechRecognizer: SFSpeechRecognizer) {
        // Cancel any ongoing task without calling endAudio (avoid premature finalization)
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation  // Continuous audio — more tolerant of silence
        
        // Prefer on-device but don't require it (requirement causes faster timeouts)
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false
            logger.info("On-device speech recognition available (preferred, not required)")
        }
        
        recognitionRequest = request
        
        // Flush any buffered audio that arrived during restart
        for buffer in pendingBuffers {
            request.append(buffer)
        }
        if !pendingBuffers.isEmpty {
            logger.info("Flushed \(self.pendingBuffers.count) pending buffers into new recognition request")
        }
        pendingBuffers.removeAll()
        isRestarting = false
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.currentTranscript = transcript
                self.updateTranscriptBuffer(transcript)
                
                if result.isFinal {
                    self.logger.info("Final transcript received, restarting recognition")
                    self.restartRecognition()
                }
            }
            
            if let error = error as NSError? {
                // Error 1110 = "No speech detected" — normal during silence, just restart
                if error.domain == "kAFAssistantErrorDomain" && error.code == 1110 {
                    self.logger.info("No speech detected (1110), restarting recognition seamlessly")
                } else {
                    self.logger.error("Recognition error: \(error)")
                }
                self.restartRecognition()
            }
        }
        
        isRecognizing = true
        logger.info("Speech recognition started")
    }
    
    private var appendedBufferCount: Int = 0
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionQueue.async { [weak self] in
            guard let self else { return }
            if self.isRestarting {
                // Buffer audio during restart so nothing is lost
                self.pendingBuffers.append(buffer)
            } else if let request = self.recognitionRequest {
                request.append(buffer)
                self.appendedBufferCount += 1
                if self.appendedBufferCount == 1 {
                    self.logger.info("\u{2705} First buffer appended to recognitionRequest — speech pipeline active")
                } else if self.appendedBufferCount % 50 == 0 {
                    self.logger.info("Speech recognizer: \(self.appendedBufferCount) buffers appended")
                }
            } else {
                // This is the BUG case — recognitionRequest is nil, buffer is LOST
                self.logger.warning("\u{26A0}\u{FE0F} processAudioBuffer called but recognitionRequest is nil — buffer DROPPED")
            }
        }
    }
    
    @discardableResult
    func stopRecognition() -> String {
        recognitionQueue.sync { [weak self] in
            guard let self else { return "" }
            self.isRecognizing = false
            self.isRestarting = false
            self.pendingBuffers.removeAll()
            self.recognitionRequest?.endAudio()
            self.recognitionTask?.cancel()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            
            let finalTranscript = self.getFullTranscript()
            self.currentTranscript = ""
            return finalTranscript
        }
    }
    
    private func restartRecognition() {
        recognitionQueue.async { [weak self] in
            guard let self, self.isRecognizing else { return }
            
            // Mark as restarting so processAudioBuffer buffers incoming audio
            self.isRestarting = true
            
            // Don't call endAudio() — it causes the 1110 error in the first place
            // Just nil out and create a fresh request
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            
            guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else {
                self.logger.error("Speech recognizer not available for restart")
                return
            }
            
            // Restart immediately — no delay (the 0.5s gap was causing lost audio)
            self._startRecognitionOnQueue(speechRecognizer: speechRecognizer)
        }
    }
    
    private func updateTranscriptBuffer(_ newTranscript: String) {
        let words = newTranscript.split(separator: " ").map(String.init)
        
        // Keep rolling window of recent words
        if words.count > maxTranscriptWords {
            let startIndex = words.count - maxTranscriptWords
            transcriptBuffer = Array(words[startIndex...])
        } else {
            transcriptBuffer = words
        }
    }
    
    func getFullTranscript() -> String {
        return transcriptBuffer.joined(separator: " ")
    }
    
    func getRecentTranscript(seconds: Int = 30) -> String {
        // Approximate: ~150 words per minute, so 30 seconds ≈ 75 words
        let recentWords = transcriptBuffer.suffix(75)
        return recentWords.joined(separator: " ")
    }
}
