The FactShield project utilizes a native iOS build system centered around **Xcode** and **Swift Package Manager (SPM)**, with a custom API-driven deployment strategy for GitHub.

### Build System & Tools
- **Primary IDE:** Xcode (required for SwiftUI, WidgetKit, and AppIntents compilation).
- **Dependency Management:** Swift Package Manager (`Package.swift`), currently configured with no external dependencies, relying on Apple's native frameworks (AVFoundation, Speech, ActivityKit).
- **Language/Version:** Swift 5.9+, targeting iOS 17.0+ to support interactive Dynamic Island features and `@Observable` MVVM architecture.

### Project Structure & Targets
- **Main App Target:** `FactShield` contains the core logic, UI, and services.
- **Broadcast Extension Target:** `FactShieldBroadcast` is a separate target required for ReplayKit system audio capture, enabling fact-checking of other apps' audio output.
- **Configuration:** Capabilities such as Background Modes (Audio, Fetch), App Groups (`group.com.factshield.shared`), and Microphone/Speech permissions are managed via `Info.plist` and Xcode Signing & Capabilities settings.

### Deployment & CI/CD
- **Manual/API-Based Push:** The repository includes `push-via-api.sh`, a bash script that bypasses standard `git push` by using the GitHub REST API to create blobs, trees, and commits directly. This suggests a workflow designed for environments where standard Git SSH/HTTPS might be restricted or for automated documentation syncing.
- **Documentation-Driven Build:** The primary "build instruction" is `FactShield-iOS-BuildInstructions.md`, which serves as the single source of truth for setting up the Xcode project, configuring entitlements, and implementing core features step-by-step.

### Developer Conventions
- **No Makefile/Docker:** As a pure iOS client-side application, there are no containerized build steps or Makefiles. Compilation is handled exclusively by Xcode's build system.
- **Incremental Implementation:** Developers are instructed to build incrementally (Audio → Speech → Claims → UI) ensuring each component compiles before proceeding, as detailed in the build instructions.