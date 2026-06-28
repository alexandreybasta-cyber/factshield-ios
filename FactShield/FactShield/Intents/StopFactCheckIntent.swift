import AppIntents

/// LiveActivityIntent conformance is required for iOS 17+ so that buttons
/// inside Live Activity / Dynamic Island expanded views can trigger this intent.
struct StopFactCheckIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Fact-Check"
    static var description: IntentDescription = "Stop the current fact-checking session"
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // The coordinator handles all cleanup (audio, speech, activity, session)
        await FactCheckCoordinator.shared.stopSession()
        
        return .result()
    }
}
