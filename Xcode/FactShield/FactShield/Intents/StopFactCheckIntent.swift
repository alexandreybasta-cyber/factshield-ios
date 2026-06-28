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
