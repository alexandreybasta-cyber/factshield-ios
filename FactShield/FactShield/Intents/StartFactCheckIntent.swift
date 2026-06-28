import AppIntents
import ActivityKit

struct StartFactCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Fact-Check"
    static var description: IntentDescription = "Start listening and fact-checking audio from any app"
    static var openAppWhenRun: Bool = false  // MUST be static — run in background like Shazam
    
    // NO @MainActor — allows the system to run this intent entirely in the background
    // without needing to foreground the app for main-thread access.
    func perform() async throws -> some IntentResult {
        // The coordinator handles the entire pipeline in the correct order.
        // startSession() is @MainActor so it will hop to main actor internally,
        // but the intent itself doesn't require foreground execution.
        await FactCheckCoordinator.shared.startSession()
        
        return .result()
    }
}
