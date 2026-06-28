# FactShield iOS App — Build Instructions for Qoder

You are building a live fact-checking iOS app called **FactShield**. The app captures audio from any other app (Instagram, YouTube, Spotify, etc.) via the Action Button, analyzes it in real-time, and shows verdicts in the Dynamic Island.

This document contains all architectural decisions, tech stack choices, code patterns, and step-by-step instructions. Follow it precisely.

---

## Project Overview

**What it does:** User presses their iPhone Action Button while watching/listening to any app. FactShield captures the audio, transcribes it, extracts verifiable claims, searches evidence across multiple sources, cross-checks them, and returns a verdict (TRUE, SUBSTANTIALLY TRUE, MISLEADING, FALSE, UNVERIFIABLE) displayed in the Dynamic Island.

**Key constraint:** This is an iOS-only app. No backend server is needed for Phase 1 — all fact-checking logic will be handled by a remote API (Qwen via HTTP). The app is the client.

**Minimum iOS version:** iOS 17.0 (required for interactive Dynamic Island buttons and AppIntents).

---

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (no UIKit unless absolutely necessary)
- **Architecture:** MVVM with @Observable macro (iOS 17+)
- **Networking:** URLSession with async/await
- **Audio:** AVAudioEngine with Voice Processing I/O (for Acoustic Echo Cancellation)
- **Transcription:** Apple Speech framework (SFSpeechRecognizer) for on-device; fallback to Whisper API if needed
- **Live Activities:** ActivityKit + WidgetKit
- **Intents:** AppIntents framework
- **Persistence:** SwiftData for caching previous fact-checks
- **Concurrency:** Swift Concurrency (async/await, actors)
- **Package Manager:** Swift Package Manager (no CocoaPods or Carthage)
- **Minimum deployment:** iOS 17.0

---

## Project Structure

```
FactShield/
├── FactShieldApp.swift                    # App entry point
├── App/
│   ├── FactShieldApp.swift
│   ├── AppState.swift                     # Global app state
│   └── NavigationRouter.swift
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── HistoryCardView.swift
│   ├── FactCheck/
│   │   ├── FactCheckSessionView.swift
│   │   ├── FactCheckSessionViewModel.swift
│   │   └── VerdictDetailView.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
├── Core/
│   ├── Audio/
│   │   ├── AudioCaptureService.swift      # AVAudioEngine + AEC
│   │   ├── AudioBufferProcessor.swift     # PCM buffer management
│   │   └── AudioSessionManager.swift      # AVAudioSession configuration
│   ├── Speech/
│   │   ├── SpeechRecognitionService.swift # SFSpeechRecognizer
│   │   └── TranscriptManager.swift        # Rolling transcript buffer
│   ├── Claims/
│   │   ├── ClaimExtractionService.swift   # Qwen API for claim extraction
│   │   ├── Claim.swift                    # Claim model
│   │   └── ClaimCheckWorthinessFilter.swift
│   ├── Verification/
│   │   ├── EvidenceRetrievalService.swift # Multi-source search
│   │   ├── VerdictSynthesisService.swift  # NLI + chain-of-thought
│   │   ├── Verdict.swift                  # Verdict model
│   │   └── SourceRanking.swift            # Source credibility scoring
│   ├── Network/
│   │   ├── APIClient.swift                # Generic HTTP client
│   │   ├── QwenAPI.swift                  # Qwen-specific endpoints
│   │   ├── SearchAPI.swift                # Tavily/Google Fact Check
│   │   └── WebSocketClient.swift          # For future backend integration
│   └── Storage/
│       ├── FactCheckHistoryStore.swift    # SwiftData store
│       └── CacheManager.swift
├── Widgets/
│   ├── FactShieldWidget.swift             # WidgetKit entry
│   ├── FactShieldLiveActivity.swift       # Live Activity definition
│   ├── DynamicIslandLayouts.swift         # Compact/Minimal/Expanded
│   └── WidgetBundle.swift
├── Intents/
│   ├── StartFactCheckIntent.swift         # Action Button start
│   ├── StopFactCheckIntent.swift          # Action Button stop
│   └── FactShieldShortcuts.swift          # AppShortcutsProvider
├── BroadcastExtension/                    # ReplayKit Broadcast Upload Extension target
│   ├── SampleHandler.swift
│   └── Info.plist
├── Models/
│   ├── FactCheckSession.swift             # Session model
│   ├── Source.swift                       # Source model
│   └── Enums.swift
├── Utilities/
│   ├── Logger.swift                       # OSLog wrapper
│   ├── Constants.swift
│   └── Extensions/
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

## Phase 1: Project Setup

### Step 1: Create Xcode Project

Create a new Xcode project:
- Template: App (iOS)
- Product Name: FactShield
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Minimum Deployments: iOS 17.0
- Include Tests: Yes

### Step 2: Add Required Capabilities

In the target's Signing & Capabilities, add:
1. **Background Modes** — Audio, AirPlay, and Picture in Picture; Background fetch
2. **Push Notifications** — For APNs push-to-start and push-to-update
3. **App Groups** — Create group `group.com.factshield.shared` (needed for Broadcast Extension data sharing)
4. **Microphone Usage Description** — "FactShield needs microphone access to capture audio for fact-checking"
5. **Speech Recognition Usage Description** — "FactShield uses speech recognition to transcribe audio for fact-checking"

### Step 3: Add the Broadcast Upload Extension Target

File → New → Target → Broadcast Upload Extension:
- Product Name: FactShieldBroadcast
- Bundle ID suffix: `.broadcast`
- App Group: `group.com.factshield.shared`
- This will create `SampleHandler.swift` — we'll implement it later

---

## Phase 2: Core Audio Capture

### Step 4: AudioSessionManager.swift

```swift
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
```

**Why `.voiceChat` mode:** This is the critical setting that enables iOS's built-in Acoustic Echo Cancellation. It's the same mode Shazam uses. When the phone is playing audio from another app (YouTube, Instagram), the AEC subtracts the known speaker output from the microphone input, isolating the actual audio content. Without this mode, the captured audio would be dominated by speaker echo.

**Why `.mixWithOthers`:** Allows FactShield to capture audio while other apps continue playing. Without this, activating our audio session would pause YouTube/Spotify.

### Step 5: AudioCaptureService.swift

```swift
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
```

### Step 6: AudioBufferProcessor.swift

This class receives PCM buffers from the capture service and feeds them to the speech recognizer.

```swift
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
```

---

## Phase 3: Speech Recognition

### Step 7: SpeechRecognitionService.swift

```swift
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
                self?.logger.warning("Speech recognition not authorized: \(status)")
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
```

**Key decisions:**
- `requiresOnDeviceRecognition = true` when available — this is faster and works offline. iOS 17+ supports on-device recognition for English, Spanish, French, German, Italian, Portuguese, Chinese, Japanese, Korean, and Arabic.
- `shouldReportPartialResults = true` — we need real-time transcript updates for the Dynamic Island.
- `addsPunctuation = true` — helps the claim extraction model identify sentence boundaries.
- Auto-restart on error — SFSpeechRecognition can fail due to network issues or silence; we auto-restart.
- Rolling 2000-word buffer — enough context for claim extraction without overwhelming the API.

---

## Phase 4: Claim Extraction

### Step 8: Claim.swift

```swift
import Foundation

struct Claim: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let timestamp: Date
    let speaker: String?
    let checkWorthiness: CheckWorthiness
    let status: ClaimStatus
    
    enum CheckWorthiness: String, Codable, Hashable {
        case high      // Factual claim with clear truth value
        case medium    // Somewhat verifiable
        case low       // Opinion, vague, or trivial
    }
    
    enum ClaimStatus: String, Codable, Hashable {
        case pending
        case extracting
        case searching
        case verifying
        case complete
        case failed
    }
}

extension Claim {
    static let empty = Claim(
        id: UUID(),
        text: "",
        timestamp: Date(),
        speaker: nil,
        checkWorthiness: .low,
        status: .pending
    )
}
```

### Step 9: ClaimExtractionService.swift

This service sends transcript chunks to Qwen API and extracts verifiable claims.

```swift
import Foundation
import OSLog

@Observable
final class ClaimExtractionService {
    static let shared = ClaimExtractionService()
    
    private let apiClient = QwenAPI.shared
    private let logger = Logger(subsystem: "com.factshield.claims", category: "ClaimExtraction")
    
    // Extracted claims
    var claims: [Claim] = []
    var isExtracting: Bool = false
    
    /// Extract verifiable claims from a transcript chunk
    func extractClaims(from transcript: String) async throws -> [Claim] {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        isExtracting = true
        defer { isExtracting = false }
        
        let prompt = """
        You are a fact-checking assistant. Analyze the following transcript and extract all verifiable factual claims.
        
        Rules:
        - Only extract claims that can be objectively verified (statistics, dates, names, events, scientific facts)
        - Skip opinions, predictions about the future, and trivial statements
        - For each claim, rate its check-worthiness: "high" (important factual claim), "medium" (somewhat verifiable), "low" (opinion or vague)
        - Return a JSON array of objects with "text" and "checkWorthiness" fields
        
        Transcript:
        \(transcript)
        
        Return ONLY the JSON array, no additional text.
        """
        
        let response = try await apiClient.chatCompletion(
            model: "qwen-plus",
            messages: [
                ["role": "system", "content": "You are a fact-checking claim extraction assistant. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.1,
            responseFormat: ["type": "json_object"]
        )
        
        guard let content = response["choices"]?[0]?["message"]?["content"]?.stringValue else {
            logger.error("No content in Qwen response")
            return []
        }
        
        let extracted = try parseClaims(from: content)
        claims.append(contentsOf: extracted)
        logger.info("Extracted \(extracted.count) claims from transcript")
        return extracted
    }
    
    private func parseClaims(from json: String) throws -> [Claim] {
        struct ClaimResponse: Codable {
            let claims: [ClaimItem]
            
            struct ClaimItem: Codable {
                let text: String
                let checkWorthiness: String
            }
        }
        
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(ClaimResponse.self, from: data)
        
        return decoded.claims.map { item in
            Claim(
                id: UUID(),
                text: item.text,
                timestamp: Date(),
                speaker: nil,
                checkWorthiness: CheckWorthiness(rawValue: item.checkWorthiness) ?? .medium,
                status: .pending
            )
        }
    }
}
```

### Step 10: QwenAPI.swift

```swift
import Foundation
import OSLog

final class QwenAPI {
    static let shared = QwenAPI()
    
    private let baseURL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    private let logger = Logger(subsystem: "com.factshield.api", category: "QwenAPI")
    
    // API key — in production, use Keychain
    private var apiKey: String {
        // TODO: Load from Keychain or environment
        return ProcessInfo.processInfo.environment["QWEN_API_KEY"] ?? ""
    }
    
    func chatCompletion(
        model: String = "qwen-plus",
        messages: [[String: String]],
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        responseFormat: [String: String]? = nil
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        
        if let responseFormat {
            body["response_format"] = responseFormat
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        logger.info("Sending request to Qwen API: model=\(model), messages=\(messages.count)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Qwen API error: \(httpResponse.statusCode) - \(errorBody)")
            throw APIError.httpError(httpResponse.statusCode, errorBody)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidJSON
        }
        
        return json
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int, String)
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        case .invalidJSON: return "Invalid JSON response"
        }
    }
}
```

---

## Phase 5: Evidence Retrieval

### Step 11: EvidenceRetrievalService.swift

```swift
import Foundation
import OSLog

struct Evidence: Identifiable, Codable, Hashable {
    let id: UUID
    let claimId: UUID
    let source: Source
    let snippet: String
    let relevanceScore: Double
    let credibilityScore: Double
    let retrievedAt: Date
    
    var weightedScore: Double {
        relevanceScore * 0.6 + credibilityScore * 0.4
    }
}

@Observable
final class EvidenceRetrievalService {
    static let shared = EvidenceRetrievalService()
    
    private let logger = Logger(subsystem: "com.factshield.verification", category: "EvidenceRetrieval")
    
    // Minimum sources required for cross-verification
    private let minSources = 3
    private let maxSources = 5
    
    /// Retrieve evidence for a claim from multiple sources
    func retrieveEvidence(for claim: Claim) async throws -> [Evidence] {
        var allEvidence: [Evidence] = []
        
        // Parallel retrieval from multiple sources
        async let tavilyResults = searchTavily(query: claim.text)
        async let googleFactCheck = searchGoogleFactCheck(query: claim.text)
        async let newsSearch = searchNews(query: claim.text)
        
        let results = try await [tavilyResults, googleFactCheck, newsSearch]
        
        for result in results {
            allEvidence.append(contentsOf: result)
        }
        
        // Deduplicate by URL
        var seen = Set<String>()
        allEvidence = allEvidence.filter { evidence in
            let key = evidence.source.url
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
        
        // Sort by weighted score (relevance + credibility)
        allEvidence.sort { $0.weightedScore > $1.weightedScore }
        
        // Take top N sources
        let topEvidence = Array(allEvidence.prefix(maxSources))
        
        logger.info("Retrieved \(topEvidence.count) evidence sources for claim: \(claim.text.prefix(50))")
        return topEvidence
    }
    
    private func searchTavily(query: String) async throws -> [Evidence] {
        // TODO: Implement Tavily API integration
        // For Phase 1, return empty — will be added in backend integration
        return []
    }
    
    private func searchGoogleFactCheck(query: String) async throws -> [Evidence] {
        // TODO: Implement Google Fact Check Tools API
        return []
    }
    
    private func searchNews(query: String) async throws -> [Evidence] {
        // TODO: Implement news search API
        return []
    }
}
```

---

## Phase 6: Verdict Synthesis

### Step 12: Verdict.swift

```swift
import Foundation

struct Verdict: Identifiable, Codable, Hashable {
    let id: UUID
    let claimId: UUID
    let verdictType: VerdictType
    let confidenceScore: Double  // 0.0 to 1.0
    let reasoning: String
    let sources: [Source]
    let timestamp: Date
    let elapsedSeconds: Int
    
    enum VerdictType: String, Codable, Hashable, CaseIterable {
        case `true` = "TRUE"
        case substantiallyTrue = "SUBSTANTIALLY TRUE"
        case misleading = "MISLEADING"
        case `false` = "FALSE"
        case unverifiable = "UNVERIFIABLE"
        
        var color: String {
            switch self {
            case .true: return "green"
            case .substantiallyTrue: return "yellow"
            case .misleading: return "orange"
            case .false: return "red"
            case .unverifiable: return "gray"
            }
        }
    }
}

struct Source: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let url: String
    let credibilityScore: Double  // 0.0 to 1.0
    let biasRating: String?       // "left", "center", "right"
    let snippet: String
}
```

### Step 13: VerdictSynthesisService.swift

```swift
import Foundation
import OSLog

@Observable
final class VerdictSynthesisService {
    static let shared = VerdictSynthesisService()
    
    private let apiClient = QwenAPI.shared
    private let logger = Logger(subsystem: "com.factshield.verification", category: "VerdictSynthesis")
    
    /// Synthesize a verdict from evidence using chain-of-thought reasoning
    func synthesizeVerdict(claim: Claim, evidence: [Evidence]) async throws -> Verdict {
        let startTime = Date()
        
        let evidenceText = evidence.enumerated().map { index, e in
            """
            Source \(index + 1): \(e.source.name) (Credibility: \(e.credibilityScore)/1.0, Bias: \(e.source.biasRating ?? "unknown"))
            Snippet: \(e.snippet)
            URL: \(e.source.url)
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        You are a professional fact-checker. Analyze the claim against the provided evidence and render a verdict.
        
        Claim: \(claim.text)
        
        Evidence:
        \(evidenceText)
        
        Instructions:
        1. First, think step by step about what the evidence says
        2. Compare the claim against each piece of evidence
        3. Consider source credibility and potential bias
        4. If evidence conflicts, explain which is more reliable and why
        5. Render one of these verdicts: TRUE, SUBSTANTIALLY TRUE, MISLEADING, FALSE, UNVERIFIABLE
        6. Provide a confidence score from 0.0 to 1.0
        7. Write a clear, concise reasoning summary (2-3 sentences)
        
        Return JSON with these fields:
        - "verdict": one of the five verdict types
        - "confidence": number between 0.0 and 1.0
        - "reasoning": string explaining the verdict
        - "sourceAnalysis": array of objects with "sourceName", "supportsClaim" (boolean), "credibility" (number)
        
        Return ONLY the JSON.
        """
        
        let response = try await apiClient.chatCompletion(
            model: "qwen-max",
            messages: [
                ["role": "system", "content": "You are an expert fact-checker. Be rigorous, non-biased, and transparent about uncertainty. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            temperature: 0.2,
            responseFormat: ["type": "json_object"]
        )
        
        guard let content = response["choices"]?[0]?["message"]?["content"]?.stringValue else {
            throw SynthesisError.noContent
        }
        
        let verdict = try parseVerdict(from: content, claimId: claim.id, evidence: evidence, startTime: startTime)
        logger.info("Verdict synthesized: \(verdict.verdictType.rawValue) (confidence: \(verdict.confidenceScore))")
        return verdict
    }
    
    private func parseVerdict(from json: String, claimId: UUID, evidence: [Evidence], startTime: Date) throws -> Verdict {
        struct VerdictResponse: Codable {
            let verdict: String
            let confidence: Double
            let reasoning: String
            let sourceAnalysis: [SourceAnalysis]
            
            struct SourceAnalysis: Codable {
                let sourceName: String
                let supportsClaim: Bool
                let credibility: Double
            }
        }
        
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(VerdictResponse.self, from: data)
        
        let verdictType = Verdict.VerdictType(rawValue: decoded.verdict.uppercased()) ?? .unverifiable
        let elapsed = Int(Date().timeIntervalSince(startTime))
        
        return Verdict(
            id: UUID(),
            claimId: claimId,
            verdictType: verdictType,
            confidenceScore: max(0, min(1, decoded.confidence)),
            reasoning: decoded.reasoning,
            sources: evidence.map { $0.source },
            timestamp: Date(),
            elapsedSeconds: elapsed
        )
    }
}

enum SynthesisError: Error, LocalizedError {
    case noContent
    case invalidJSON
    
    var errorDescription: String? {
        switch self {
        case .noContent: return "No content in API response"
        case .invalidJSON: return "Failed to parse verdict JSON"
        }
    }
}
```

---

## Phase 7: Dynamic Island & Live Activities

### Step 14: FactShieldLiveActivity.swift

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct FactCheckAttributes: ActivityAttributes {
    var captureMode: CaptureMode
    var sourceApp: String?
    var startedAt: Date
    
    public struct ContentState: Codable, Hashable {
        var status: VerificationStatus
        var verdict: VerdictType?
        var confidenceScore: Double
        var sourceCount: Int
        var topSources: [String]
        var reasoningSummary: String?
        var claimText: String?
        var elapsedSeconds: Int
        var updatedAt: Date
    }
    
    enum CaptureMode: String, Codable, Hashable {
        case microphone = "Microphone"
        case replayKit = "System Audio"
    }
    
    enum VerificationStatus: String, Codable, Hashable {
        case listening = "Listening..."
        case transcribing = "Transcribing..."
        case extracting = "Extracting claims..."
        case searching = "Searching evidence..."
        case verifying = "Cross-checking..."
        case complete = "Complete"
    }
    
    enum VerdictType: String, Codable, Hashable {
        case `true` = "TRUE"
        case substantiallyTrue = "SUBSTANTIALLY TRUE"
        case misleading = "MISLEADING"
        case `false` = "FALSE"
        case unverifiable = "UNVERIFIABLE"
    }
}
```

### Step 15: FactShieldWidget.swift (WidgetKit)

```swift
import WidgetKit
import SwiftUI
import ActivityKit

struct FactShieldLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FactCheckAttributes.self) { context in
            // Lock screen / banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded layout (when user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
    }
    
    // MARK: - Lock Screen View
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.blue)
                Text("FactShield")
                    .font(.headline)
                Spacer()
                Text(context.state.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let claim = context.state.claimText {
                Text(claim)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            if let verdict = context.state.verdict {
                HStack {
                    VerdictBadge(verdict: verdict, confidence: context.state.confidenceScore)
                    Spacer()
                    Text("\(context.state.sourceCount) sources")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.black.opacity(0.8))
    }
    
    // MARK: - Dynamic Island: Compact Leading
    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(statusColor(context.state.status))
            .symbolEffect(.pulse, isActive: context.state.status != .complete)
    }
    
    // MARK: - Dynamic Island: Compact Trailing
    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        if let verdict = context.state.verdict {
            Text(verdict.rawValue)
                .font(.caption2.bold())
                .foregroundStyle(verdictColor(verdict))
        } else {
            Text(context.state.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Dynamic Island: Minimal
    @ViewBuilder
    private func minimalView(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        Image(systemName: "checkmark.shield.fill")
            .foregroundStyle(statusColor(context.state.status))
            .symbolEffect(.pulse, isActive: context.state.status != .complete)
    }
    
    // MARK: - Dynamic Island: Expanded Regions
    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("FactShield")
                .font(.caption2.bold())
            Text(context.state.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let verdict = context.state.verdict {
                Text(verdict.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(verdictColor(verdict))
                Text("\(Int(context.state.confidenceScore * 100))% confident")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(context.state.elapsedSeconds)s")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        VStack(spacing: 4) {
            if let claim = context.state.claimText {
                Text(claim)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<FactCheckAttributes>) -> some View {
        HStack {
            if let verdict = context.state.verdict {
                VerdictBadge(verdict: verdict, confidence: context.state.confidenceScore)
                
                Spacer()
                
                if let reasoning = context.state.reasoningSummary {
                    Text(reasoning)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Analyzing...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Helper Views
    private func statusColor(_ status: FactCheckAttributes.VerificationStatus) -> Color {
        switch status {
        case .listening: return .blue
        case .transcribing: return .cyan
        case .extracting: return .orange
        case .searching: return .purple
        case .verifying: return .yellow
        case .complete: return .green
        }
    }
    
    private func verdictColor(_ verdict: FactCheckAttributes.VerdictType) -> Color {
        switch verdict {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}

struct VerdictBadge: View {
    let verdict: FactCheckAttributes.VerdictType
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(verdictColor(verdict))
                .frame(width: 8, height: 8)
            Text(verdict.rawValue)
                .font(.caption2.bold())
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(verdictColor(verdict).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func verdictColor(_ verdict: FactCheckAttributes.VerdictType) -> Color {
        switch verdict {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
}
```

### Step 16: ActivityManager.swift

```swift
import ActivityKit
import OSLog

@Observable
final class ActivityManager {
    static let shared = ActivityManager()
    
    private let logger = Logger(subsystem: "com.factshield.activity", category: "ActivityManager")
    private var currentActivity: Activity<FactCheckAttributes>?
    
    var isActivityRunning: Bool {
        currentActivity != nil
    }
    
    @MainActor
    func startLiveActivity(captureMode: FactCheckAttributes.CaptureMode = .microphone, sourceApp: String? = nil) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.error("Live Activities not enabled")
            throw ActivityError.notEnabled
        }
        
        let attributes = FactCheckAttributes(
            captureMode: captureMode,
            sourceApp: sourceApp,
            startedAt: Date()
        )
        
        let initialState = FactCheckAttributes.ContentState(
            status: .listening,
            verdict: nil,
            confidenceScore: 0.0,
            sourceCount: 0,
            topSources: [],
            reasoningSummary: nil,
            claimText: nil,
            elapsedSeconds: 0,
            updatedAt: Date()
        )
        
        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil),
            pushType: .token  // Enable APNs push updates
        )
        
        currentActivity = activity
        logger.info("Live Activity started with push token: \(activity.pushToken?.hexString ?? "none")")
    }
    
    @MainActor
    func updateActivity(state: FactCheckAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
        logger.info("Live Activity updated: status=\(state.status.rawValue)")
    }
    
    @MainActor
    func endActivity(finalState: FactCheckAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        
        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
        currentActivity = nil
        logger.info("Live Activity ended")
    }
}

enum ActivityError: Error, LocalizedError {
    case notEnabled
    case alreadyRunning
    
    var errorDescription: String? {
        switch self {
        case .notEnabled: return "Live Activities are not enabled on this device"
        case .alreadyRunning: return "A fact-checking session is already running"
        }
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
```

---

## Phase 8: AppIntents for Action Button

### Step 17: StartFactCheckIntent.swift

```swift
import AppIntents
import ActivityKit

struct StartFactCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Fact-Check"
    static var description: IntentDescription = "Start listening and fact-checking audio from any app"
    static var openAppWhenRun: Bool = false  // Don't open the app — run in background
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Configure audio session
        try await AudioSessionManager.shared.configureForCapture()
        
        // Start audio capture
        AudioCaptureService.shared.startListening()
        
        // Start speech recognition
        SpeechRecognitionService.shared.startRecognition()
        
        // Start Live Activity
        try await ActivityManager.shared.startLiveActivity()
        
        // Start the fact-checking pipeline coordinator
        FactCheckCoordinator.shared.startSession()
        
        return .result()
    }
}
```

### Step 18: StopFactCheckIntent.swift

```swift
import AppIntents

struct StopFactCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Fact-Check"
    static var description: IntentDescription = "Stop the current fact-checking session"
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Stop the coordinator
        await FactCheckCoordinator.shared.stopSession()
        
        // Stop audio capture
        AudioCaptureService.shared.stopListening()
        
        // Get final transcript
        let transcript = SpeechRecognitionService.shared.stopRecognition()
        
        // Stop speech recognition
        SpeechRecognitionService.shared.stopRecognition()
        
        // Deactivate audio session
        try? await AudioSessionManager.shared.deactivate()
        
        // End Live Activity with final state
        let finalState = FactCheckAttributes.ContentState(
            status: .complete,
            verdict: FactCheckCoordinator.shared.currentVerdict?.verdictType.toActivityType(),
            confidenceScore: FactCheckCoordinator.shared.currentVerdict?.confidenceScore ?? 0,
            sourceCount: FactCheckCoordinator.shared.currentVerdict?.sources.count ?? 0,
            topSources: FactCheckCoordinator.shared.currentVerdict?.sources.map { $0.name } ?? [],
            reasoningSummary: FactCheckCoordinator.shared.currentVerdict?.reasoning,
            claimText: FactCheckCoordinator.shared.currentClaim?.text,
            elapsedSeconds: FactCheckCoordinator.shared.elapsedSeconds,
            updatedAt: Date()
        )
        
        await ActivityManager.shared.endActivity(finalState: finalState)
        
        return .result()
    }
}
```

### Step 19: FactShieldShortcuts.swift

```swift
import AppIntents

struct FactShieldShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFactCheckIntent(),
            phrases: [
                "Start fact-checking with \(.applicationName)",
                "Fact-check this with \(.applicationName)",
                "Quick fact-check with \(.applicationName)"
            ],
            shortTitle: "Fact-Check",
            systemImageName: "checkmark.shield"
        )
        
        AppShortcut(
            intent: StopFactCheckIntent(),
            phrases: [
                "Stop fact-checking with \(.applicationName)",
                "End fact-check with \(.applicationName)"
            ],
            shortTitle: "Stop Fact-Check",
            systemImageName: "xmark.shield"
        )
    }
}
```

**User setup:** After installing the app, the user goes to Settings → Action Button → selects "FactShield" → assigns "Quick Fact-Check" to the Action Button. Now pressing the Action Button from any app starts the fact-checking pipeline.

---

## Phase 9: The Fact-Check Coordinator

### Step 20: FactCheckCoordinator.swift

This is the brain that orchestrates the entire pipeline: audio capture → transcription → claim extraction → evidence retrieval → verdict synthesis.

```swift
import Foundation
import OSLog
import Combine

@Observable
final class FactCheckCoordinator {
    static let shared = FactCheckCoordinator()
    
    private let logger = Logger(subsystem: "com.factshield.core", category: "FactCheckCoordinator")
    
    // Services
    private let audioCapture = AudioCaptureService.shared
    private let speechRecognizer = SpeechRecognitionService.shared
    private let claimExtractor = ClaimExtractionService.shared
    private let evidenceRetriever = EvidenceRetrievalService.shared
    private let verdictSynthesizer = VerdictSynthesisService.shared
    private let activityManager = ActivityManager.shared
    
    // State
    var currentClaim: Claim?
    var currentVerdict: Verdict?
    var sessionTranscript: String = ""
    var isRunning: Bool = false
    var elapsedSeconds: Int = 0
    
    // Timers
    private var extractionTimer: Timer?
    private var elapsedTimer: Timer?
    private var lastExtractionTime: Date?
    
    // How often to extract claims from the rolling transcript
    private let extractionInterval: TimeInterval = 15.0  // Every 15 seconds
    
    func startSession() {
        guard !isRunning else { return }
        isRunning = true
        elapsedSeconds = 0
        
        // Wire up audio buffer callback
        audioCapture.onAudioBuffer = { [weak self] buffer in
            AudioBufferProcessor.shared.processBuffer(buffer)
        }
        
        // Start periodic claim extraction
        startExtractionTimer()
        
        // Start elapsed time counter
        startElapsedTimer()
        
        logger.info("Fact-check session started")
    }
    
    func stopSession() async {
        isRunning = false
        extractionTimer?.invalidate()
        extractionTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        logger.info("Fact-check session stopped")
    }
    
    // MARK: - Periodic Claim Extraction
    private func startExtractionTimer() {
        extractionTimer = Timer.scheduledTimer(withTimeInterval: extractionInterval, repeats: true) { [weak self] _ in
            Task { await self?.extractAndVerify() }
        }
        // Also run immediately
        Task { await extractAndVerify() }
    }
    
    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.elapsedSeconds += 1
            Task { @MainActor in
                await self.updateActivityWithCurrentState()
            }
        }
    }
    
    @MainActor
    private func extractAndVerify() async {
        let transcript = speechRecognizer.getRecentTranscript(seconds: 30)
        
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        // Update activity: extracting
        await updateActivity(status: .extracting, claimText: nil)
        
        do {
            // Step 1: Extract claims
            let claims = try await claimExtractor.extractClaims(from: transcript)
            
            // Filter to high check-worthiness claims
            let highWorthinessClaims = claims.filter { $0.checkWorthiness == .high }
            
            guard let claim = highWorthinessClaims.first ?? claims.first else {
                return
            }
            
            currentClaim = claim
            sessionTranscript = transcript
            
            // Update activity: searching
            await updateActivity(status: .searching, claimText: claim.text)
            
            // Step 2: Retrieve evidence
            let evidence = try await evidenceRetriever.retrieveEvidence(for: claim)
            
            guard !evidence.isEmpty else {
                await updateActivity(status: .complete, claimText: claim.text)
                return
            }
            
            // Update activity: verifying
            await updateActivity(status: .verifying, claimText: claim.text)
            
            // Step 3: Synthesize verdict
            let verdict = try await verdictSynthesizer.synthesizeVerdict(claim: claim, evidence: evidence)
            currentVerdict = verdict
            
            // Update activity: complete
            await updateActivity(
                status: .complete,
                claimText: claim.text,
                verdict: verdict.verdictType.toActivityType(),
                confidence: verdict.confidenceScore,
                sourceCount: verdict.sources.count,
                reasoning: verdict.reasoning
            )
            
            logger.info("Verdict complete: \(verdict.verdictType.rawValue)")
            
        } catch {
            logger.error("Fact-check pipeline error: \(error)")
        }
    }
    
    // MARK: - Activity Updates
    @MainActor
    private func updateActivity(
        status: FactCheckAttributes.VerificationStatus,
        claimText: String?,
        verdict: FactCheckAttributes.VerdictType? = nil,
        confidence: Double = 0,
        sourceCount: Int = 0,
        reasoning: String? = nil
    ) async {
        let state = FactCheckAttributes.ContentState(
            status: status,
            verdict: verdict,
            confidenceScore: confidence,
            sourceCount: sourceCount,
            topSources: [],
            reasoningSummary: reasoning,
            claimText: claimText,
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date()
        )
        await activityManager.updateActivity(state: state)
    }
    
    @MainActor
    private func updateActivityWithCurrentState() async {
        let state = FactCheckAttributes.ContentState(
            status: isRunning ? .listening : .complete,
            verdict: currentVerdict?.verdictType.toActivityType(),
            confidenceScore: currentVerdict?.confidenceScore ?? 0,
            sourceCount: currentVerdict?.sources.count ?? 0,
            topSources: currentVerdict?.sources.map { $0.name } ?? [],
            reasoningSummary: currentVerdict?.reasoning,
            claimText: currentClaim?.text,
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date()
        )
        await activityManager.updateActivity(state: state)
    }
}

// MARK: - Verdict Type Conversion
extension Verdict.VerdictType {
    func toActivityType() -> FactCheckAttributes.VerdictType {
        switch self {
        case .true: return .true
        case .substantiallyTrue: return .substantiallyTrue
        case .misleading: return .misleading
        case .false: return .false
        case .unverifiable: return .unverifiable
        }
    }
}
```

---

## Phase 10: Home UI

### Step 21: HomeView.swift

```swift
import SwiftUI

struct HomeView: View {
    @State private var coordinator = FactCheckCoordinator.shared
    @State private var showSession = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero section
                    HeroCard(isRunning: coordinator.isRunning) {
                        showSession = true
                    }
                    
                    // How it works
                    HowItWorksSection()
                    
                    // Recent history
                    RecentHistorySection()
                }
                .padding()
            }
            .navigationTitle("FactShield")
            .sheet(isPresented: $showSession) {
                FactCheckSessionView()
            }
        }
    }
}

struct HeroCard: View {
    let isRunning: Bool
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            
            Text("Live Fact-Checking")
                .font(.title2.bold())
            
            Text("Press your Action Button while watching or listening to any content. FactShield analyzes claims in real-time and shows verdicts in your Dynamic Island.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if !isRunning {
                Button(action: onStart) {
                    Label("Start Fact-Checking", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button(action: {}) {
                    Label("Session Active", systemImage: "waveform")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(true)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct HowItWorksSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                StepRow(icon: "hand.tap.fill", title: "Press Action Button", description: "While watching any video or listening to audio")
                StepRow(icon: "waveform", title: "Audio Captured", description: "Microphone + Acoustic Echo Cancellation isolates the audio")
                StepRow(icon: "text.bubble.fill", title: "Claims Extracted", description: "AI identifies verifiable factual statements")
                StepRow(icon: "magnifyingglass", title: "Evidence Searched", description: "Multiple sources cross-checked simultaneously")
                StepRow(icon: "checkmark.seal.fill", title: "Verdict Delivered", description: "Result shown in your Dynamic Island with sources")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StepRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct RecentHistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Checks")
                .font(.headline)
            
            // TODO: Load from SwiftData
            Text("No fact-checks yet. Start your first session!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(24)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

### Step 22: FactCheckSessionView.swift

```swift
import SwiftUI

struct FactCheckSessionView: View {
    @State private var coordinator = FactCheckCoordinator.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Status indicator
                    StatusCard()
                    
                    // Current claim
                    if let claim = coordinator.currentClaim {
                        ClaimCard(claim: claim)
                    }
                    
                    // Current verdict
                    if let verdict = coordinator.currentVerdict {
                        VerdictCard(verdict: verdict)
                    }
                    
                    // Transcript
                    TranscriptCard(transcript: coordinator.sessionTranscript)
                }
                .padding()
            }
            .navigationTitle("Fact-Check Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if coordinator.isRunning {
                        Button("Stop") {
                            Task {
                                await coordinator.stopSession()
                            }
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Start") {
                            coordinator.startSession()
                        }
                    }
                }
            }
        }
    }
}

struct StatusCard: View {
    @State private var coordinator = FactCheckCoordinator.shared
    
    var body: some View {
        HStack {
            Image(systemName: coordinator.isRunning ? "waveform.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(coordinator.isRunning ? .green : .gray)
                .symbolEffect(.pulse, isActive: coordinator.isRunning)
            
            VStack(alignment: .leading) {
                Text(coordinator.isRunning ? "Active" : "Inactive")
                    .font(.headline)
                Text("Elapsed: \(coordinator.elapsedSeconds)s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ClaimCard: View {
    let claim: Claim
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Claim Detected")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            Text(claim.text)
                .font(.body)
            
            HStack {
                Label(claim.checkWorthiness.rawValue.capitalized, systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(checkWorthinessColor(claim.checkWorthiness))
                
                Spacer()
                
                Text(claim.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func checkWorthinessColor(_ worthiness: Claim.CheckWorthiness) -> Color {
        switch worthiness {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}

struct VerdictCard: View {
    let verdict: Verdict
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verdict.verdictType.rawValue)
                    .font(.title3.bold())
                    .foregroundStyle(verdictColor(verdict.verdictType))
                
                Spacer()
                
                Text("\(Int(verdict.confidenceScore * 100))% confident")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(verdict.reasoning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
            
            Text("Sources (\(verdict.sources.count))")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            ForEach(verdict.sources) { source in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(credibilityColor(source.credibilityScore))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.name)
                            .font(.caption.bold())
                        Text(source.snippet)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func verdictColor(_ type: Verdict.VerdictType) -> Color {
        switch type {
        case .true: return .green
        case .substantiallyTrue: return .yellow
        case .misleading: return .orange
        case .false: return .red
        case .unverifiable: return .gray
        }
    }
    
    private func credibilityColor(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.5 { return .yellow }
        return .red
    }
}

struct TranscriptCard: View {
    let transcript: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Live Transcript")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            Text(transcript.isEmpty ? "Waiting for audio..." : transcript)
                .font(.caption)
                .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                .lineLimit(10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## Phase 11: Broadcast Upload Extension (ReplayKit)

### Step 23: SampleHandler.swift

This is the entry point for the Broadcast Upload Extension. It captures system audio when the user starts a screen broadcast from Control Center.

```swift
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
```

**Important:** The Broadcast Extension has a ~50MB memory limit. The audio data is written to a shared file that the main app reads. For production, you'd want to implement a more sophisticated IPC mechanism using Darwin notifications or a shared memory ring buffer.

---

## Phase 12: Info.plist Configuration

### Step 24: Main App Info.plist

Add these keys:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>FactShield needs microphone access to capture audio for fact-checking.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>FactShield uses speech recognition to transcribe audio for fact-checking.</string>

<key>NSUserActivityTypes</key>
<array>
    <string>StartFactCheckIntent</string>
    <string>StopFactCheckIntent</string>
</array>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### Step 25: Broadcast Extension Info.plist

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.broadcast-services-upload</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).SampleHandler</string>
    <key>RPBroadcastProcessMode</key>
    <string>RPBroadcastProcessModeSampleBuffer</string>
</dict>
```

---

## Phase 13: Testing Checklist

### Step 26: Test Each Component

1. **Audio Capture:** Verify that `AudioCaptureService` starts and stops correctly. Check that AEC is working by playing audio from YouTube and verifying the captured audio is clean.

2. **Speech Recognition:** Verify `SpeechRecognitionService` produces real-time transcripts. Test with different accents and background noise levels.

3. **Claim Extraction:** Send sample transcripts to `ClaimExtractionService` and verify the extracted claims are accurate and properly rated for check-worthiness.

4. **Dynamic Island:** Start a Live Activity and verify all three layouts (compact, minimal, expanded) render correctly. Verify status updates propagate in real-time.

5. **Action Button:** Assign "Quick Fact-Check" to the Action Button in Settings. Press it from another app and verify the pipeline starts.

6. **End-to-End:** Start a session, play a YouTube video with clear factual claims, and verify the full pipeline: capture → transcribe → extract → search → verdict → Dynamic Island.

### Known Limitations for Phase 1

- Evidence retrieval returns empty results (API keys not yet configured)
- Verdict synthesis will fail without evidence (mock data needed for testing)
- Broadcast Extension audio passing is basic (file-based, not real-time)
- No offline support
- No caching of previous fact-checks

---

## Key Architecture Decisions Summary

1. **Agent lives on the backend, not in the app.** The iOS app is a thin client that captures audio and displays results. All AI logic runs via HTTP API calls.

2. **Two capture modes:** Mode A (microphone + AEC) is the primary, frictionless path. Mode B (ReplayKit broadcast) is the high-fidelity fallback for when audio quality matters.

3. **Dynamic Island is the primary UI during fact-checking.** The app itself is for setup, history, and detailed verdict review.

4. **Action Button is the primary entry point.** One press starts the pipeline. No need to open the app.

5. **On-device transcription when possible.** SFSpeechRecognizer with `requiresOnDeviceRecognition` is faster and works offline. Fallback to API-based Whisper when on-device isn't available.

6. **15-second claim extraction interval.** Balances responsiveness with API cost. Claims are extracted from a rolling 30-second transcript window.

7. **MVVM with @Observable.** Modern Swift concurrency patterns throughout. No Combine except where absolutely necessary.

---

## Next Steps After Phase 1

1. Integrate Tavily API and Google Fact Check Tools API for evidence retrieval
2. Add SwiftData persistence for fact-check history
3. Implement the full Broadcast Extension audio pipeline with real-time IPC
4. Add multi-language support (Spanish, French, Arabic, Portuguese)
5. Add Siri integration ("Hey Siri, fact-check this")
6. Build the backend server (Python/FastAPI) for the full triple-verification pipeline
7. Implement APNs push-to-start for remote triggering
