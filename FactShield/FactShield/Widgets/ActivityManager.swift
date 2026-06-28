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
        logger.info("startLiveActivity() called")
        
        let authInfo = ActivityAuthorizationInfo()
        logger.info("areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        
        guard authInfo.areActivitiesEnabled else {
            logger.error("Live Activities not enabled — user must enable in Settings > FactShield > Live Activities")
            throw ActivityError.notEnabled
        }
        
        // End any existing activity first
        if let existing = currentActivity {
            logger.info("Ending existing activity before starting new one: \(existing.id)")
            await existing.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
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
            pushType: nil  // Local updates only (no APNs required)
        )
        
        currentActivity = activity
        logger.info("Live Activity started: id=\(activity.id)")
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
