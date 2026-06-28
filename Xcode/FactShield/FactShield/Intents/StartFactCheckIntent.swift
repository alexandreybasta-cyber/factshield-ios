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
