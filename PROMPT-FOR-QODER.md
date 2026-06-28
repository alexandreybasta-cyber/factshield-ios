# Prompt to Give to Qoder

Copy and paste this entire block into Qoder:

---

Build me an iOS app called **FactShield**. It's a live fact-checking app that captures audio from any other app via the iPhone Action Button, transcribes it in real-time, extracts verifiable claims, searches evidence, and shows verdicts in the Dynamic Island.

Read the file `FactShield-iOS-BuildInstructions.md` in this folder — it contains the complete step-by-step build guide with all code, architecture decisions, file structure, and implementation details. Follow it from Step 1 through Step 26.

**Key requirements:**
- Swift + SwiftUI, iOS 17+, MVVM with @Observable
- AVAudioEngine with `.voiceChat` mode (enables Acoustic Echo Cancellation — this is how Shazam captures audio while other apps play sound)
- SFSpeechRecognizer for on-device transcription
- AppIntents for Action Button integration (StartFactCheckIntent / StopFactCheckIntent)
- ActivityKit + WidgetKit for Dynamic Island with compact/minimal/expanded layouts
- Broadcast Upload Extension target for ReplayKit system audio capture
- Qwen API (qwen-plus for claim extraction, qwen-max for verdict synthesis)
- App Group `group.com.factshield.shared` for IPC between main app and broadcast extension

Start with the Xcode project setup (Step 1-3), then build the core audio pipeline (Steps 4-7), then claim extraction (Steps 8-10), then Dynamic Island (Steps 14-16), then AppIntents (Steps 17-19), then the FactCheckCoordinator (Step 20), then the UI (Steps 21-22).

Build incrementally and make sure each component compiles before moving to the next.
