import Foundation

/// Global app state observable
@Observable
final class AppState {
    static let shared = AppState()
    
    var isFactCheckingActive: Bool = false
    var currentSessionId: UUID?
    var isBroadcastActive: Bool = false
    
    // Permissions state
    var hasMicrophonePermission: Bool = false
    var hasSpeechRecognitionPermission: Bool = false
    
    // Error state
    var lastError: FactShieldError?
    var showError: Bool = false
    
    func presentError(_ error: FactShieldError) {
        lastError = error
        showError = true
    }
    
    func clearError() {
        lastError = nil
        showError = false
    }
}
