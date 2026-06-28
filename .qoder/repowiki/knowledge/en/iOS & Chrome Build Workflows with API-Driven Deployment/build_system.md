The FactShield repository employs a dual-platform build strategy, utilizing native toolchains for iOS and standard web technologies for the Chrome extension, supplemented by a custom API-driven deployment mechanism.

### iOS Build System (Xcode & SPM)
- **Primary Toolchain:** The iOS application (`FactShield/`) is built using **Xcode** and **Swift 5.9+**, targeting **iOS 17.0+**. This version constraint is critical for accessing `ActivityKit` (Dynamic Island), `AppIntents` (Action Button integration), and the `@Observable` macro.
- **Dependency Management:** Uses **Swift Package Manager (SPM)** via `Package.swift`. The project currently adheres to a **zero-dependency** philosophy for core logic, relying exclusively on Apple’s native frameworks (AVFoundation, Speech, ActivityKit, WidgetKit) to minimize supply chain risk and build complexity.
- **Multi-Target Architecture:** The Xcode project defines two primary targets:
  - **Main App:** Contains the SwiftUI interface, core audio services, and network logic.
  - **Broadcast Upload Extension:** A separate target (`FactShieldBroadcast`) required for **ReplayKit** integration, enabling high-fidelity system audio capture from other apps. This target shares data with the main app via **App Groups** (`group.com.factshield.shared`).
- **Configuration & Entitlements:** Build capabilities are managed through `Info.plist` and `.entitlements` files. Key configurations include:
  - **Background Modes:** Audio, Fetch, and Remote Notification.
  - **Privacy Permissions:** `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`.
  - **App Groups:** Shared container access for inter-process communication between the main app and broadcast extension.

### Chrome Extension Build (Manifest V3)
- **Structure:** The `FactShield-ChromeExtension/` directory follows a standard **Manifest V3** structure. It does not use a bundler (like Webpack or Vite) in its current state, relying on native ES modules (`"type": "module"` in background service worker).
- **Components:** 
  - **Service Worker:** `src/background/service-worker.js` handles lifecycle and message routing.
  - **Content Scripts:** `src/content/extractor.js` injects into target domains (YouTube, Instagram, X, etc.).
  - **Side Panel:** HTML/JS-based UI for displaying verdicts.
- **Permissions:** Requires `sidePanel`, `tabCapture`, `offscreen`, and `scripting` permissions, with host permissions for AI APIs (Qwen, Tavily, Google Fact Check).

### Deployment & CI/CD Strategy
- **API-Driven Git Push:** The repository features a unique deployment script, `push-via-api.sh`. Instead of using standard `git push` over SSH/HTTPS, this script:
  1. Authenticates with a GitHub Personal Access Token (PAT).
  2. Creates Git blobs for each file via the GitHub REST API.
  3. Constructs a tree and commit object via API calls.
  4. Updates the branch reference directly.
  *This approach bypasses local Git remote configurations and is likely used for automated syncing from environments where SSH keys are not configured or for specific CI/CD constraints.*
- **Documentation-First Build:** Due to the complexity of iOS entitlements and multi-target setups, the primary "build instruction" is `FactShield-iOS-BuildInstructions.md`. Developers are expected to manually configure Xcode capabilities (Background Modes, App Groups) as guided by this document, rather than relying on an automated provisioning script.

### Developer Conventions
- **No Containerization:** There are no `Dockerfile`s or `docker-compose.yml` files, as the iOS client is purely native and the Chrome extension runs in the browser. Backend services (if any) are external APIs.
- **Incremental Verification:** The build process emphasizes incremental verification of iOS capabilities (Audio → Speech → Claims) due to the tight coupling with hardware permissions and simulator limitations.
- **Secrets Management:** API keys (e.g., `QWEN_API_KEY`) are currently loaded via environment variables or hardcoded placeholders in development, with instructions to move to Keychain/Secure Storage for production.