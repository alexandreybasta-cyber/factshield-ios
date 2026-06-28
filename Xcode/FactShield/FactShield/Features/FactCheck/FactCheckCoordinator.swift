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
    
    // History for the session
    var allClaims: [Claim] = []
    var allVerdicts: [Verdict] = []
    
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
