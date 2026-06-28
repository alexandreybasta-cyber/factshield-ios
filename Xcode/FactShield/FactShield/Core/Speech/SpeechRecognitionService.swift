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
        
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        
        // Prefer on-device recognition when available
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            logger.info("Using on-device speech recognition")
        }
        
        recognitionRequest = request
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            
            if let result {
                let transcript = result.bestTranscription.formattedString
                self.currentTranscript = transcript
                self.updateTranscriptBuffer(transcript)
                
                if result.isFinal {
                    self.logger.info("Final transcript: \(transcript)")
                }
            }
            
            if let error {
                self.logger.error("Recognition error: \(error)")
                self.restartRecognition()
            }
        }
        
        isRecognizing = true
        logger.info("Speech recognition started")
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    @discardableResult
    func stopRecognition() -> String {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecognizing = false
        
        let finalTranscript = getFullTranscript()
        currentTranscript = ""
        return finalTranscript
    }
    
    private func restartRecognition() {
        guard isRecognizing else { return }
        
        recognitionRequest?.endAudio()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Brief delay before restart
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startRecognition()
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
