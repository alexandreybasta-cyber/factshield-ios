import Foundation
import OSLog
import Combine
import ActivityKit

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
    
    // History for the session
    var allClaims: [Claim] = []
    var allVerdicts: [Verdict] = []
    
    // Timers
    private var extractionTimer: Timer?
    private var elapsedTimer: Timer?
    private var lastExtractionTime: Date?
    
    // How often to extract claims from the rolling transcript
    private let extractionInterval: TimeInterval = 15.0  // Every 15 seconds
    
    /// Starts the full fact-checking pipeline in the correct order:
    /// 1. Wire audio buffer callback (BEFORE audio starts)
    /// 2. Start speech recognition (creates recognitionRequest)
    /// 3. Start audio capture (buffers flow through callback → recognizer)
    /// 4. Start Live Activity
    /// 5. Start extraction timers
    @MainActor
    func startSession() async {
        guard !isRunning else { return }
        isRunning = true
        elapsedSeconds = 0
        
        logger.info("Starting fact-check pipeline...")
        
        // Step 1: Wire the audio buffer callback FIRST — before any audio flows
        audioCapture.onAudioBuffer = { buffer in
            AudioBufferProcessor.shared.processBuffer(buffer)
        }
        logger.info("✓ Audio buffer callback wired")
        
        // Step 2: Configure audio session
        do {
            try await AudioSessionManager.shared.configureForCapture()
            logger.info("✓ Audio session configured")
        } catch {
            logger.error("✗ Audio session configuration failed: \(error)")
        }
        
        // Step 3: Start speech recognition (creates recognitionRequest synchronously on its queue)
        speechRecognizer.startRecognition()
        // Give the recognition queue a moment to create the request
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        logger.info("✓ Speech recognition started")
        
        // Step 4: NOW start audio capture — buffers will flow through the wired callback
        audioCapture.startListening()
        logger.info("✓ Audio capture started — buffers now flowing to speech recognizer")
        
        // Step 5: Start Live Activity (non-critical — log errors but don't fail)
        do {
            let activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            logger.info("Live Activities enabled: \(activitiesEnabled)")
            if activitiesEnabled {
                try await activityManager.startLiveActivity()
                logger.info("✓ Live Activity started")
            } else {
                logger.warning("✗ Live Activities not enabled — check Settings > FactShield > Live Activities")
            }
        } catch {
            logger.error("✗ Live Activity failed to start: \(error)")
        }
        
        // Step 6: Start periodic claim extraction
        startExtractionTimer()
        
        // Step 7: Start elapsed time counter
        startElapsedTimer()
        
        logger.info("Fact-check session fully started ✓")
    }
    
    @MainActor
    func stopSession() async {
        isRunning = false
        extractionTimer?.invalidate()
        extractionTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        
        // Stop audio capture
        audioCapture.stopListening()
        audioCapture.onAudioBuffer = nil
        
        // Stop speech recognition
        speechRecognizer.stopRecognition()
        
        // Deactivate audio session
        try? await AudioSessionManager.shared.deactivate()
        
        // End Live Activity
        let finalState = FactCheckAttributes.ContentState(
            status: .complete,
            verdict: currentVerdict?.verdictType.toActivityType(),
            confidenceScore: currentVerdict?.confidenceScore ?? 0,
            sourceCount: currentVerdict?.sources.count ?? 0,
            topSources: currentVerdict?.sources.map { $0.name } ?? [],
            reasoningSummary: currentVerdict?.reasoning,
            claimText: currentClaim?.text,
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date()
        )
        await activityManager.endActivity(finalState: finalState)
        
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
            if !allClaims.contains(where: { $0.text == claim.text }) {
                allClaims.append(claim)
            }
            
            // Update activity: searching
            await updateActivity(status: .searching, claimText: claim.text)
            
            // Step 2: Retrieve evidence
            let evidence = try await evidenceRetriever.retrieveEvidence(for: claim)
            
            // If no evidence found, use model knowledge as fallback
            if evidence.isEmpty {
                await updateActivity(status: .verifying, claimText: claim.text)
                let verdict = try await verdictSynthesizer.synthesizeVerdictWithoutEvidence(claim: claim)
                currentVerdict = verdict
                allVerdicts.append(verdict)
                await updateActivity(
                    status: .complete,
                    claimText: claim.text,
                    verdict: verdict.verdictType.toActivityType(),
                    confidence: verdict.confidenceScore,
                    sourceCount: 0,
                    reasoning: verdict.reasoning
                )
                logger.info("Verdict (no evidence): \(verdict.verdictType.rawValue)")
                return
            }
            
            // Update activity: verifying
            await updateActivity(status: .verifying, claimText: claim.text)
            
            // Step 3: Synthesize verdict
            let verdict = try await verdictSynthesizer.synthesizeVerdict(claim: claim, evidence: evidence)
            currentVerdict = verdict
            allVerdicts.append(verdict)
            
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
