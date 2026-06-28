The FactShield repository employs a **zero-dependency architecture** for its core iOS application, relying exclusively on Apple's native frameworks and the Swift Standard Library. This strategy minimizes supply chain risks, reduces binary size, and simplifies the build process by eliminating the need for external package managers like CocoaPods or Swift Package Manager (SPM) dependencies.

### iOS Dependency Strategy
- **No External Packages**: The `FactShield/Package.swift` file explicitly defines an empty `dependencies: []` array. All functionality is implemented using native iOS APIs such as `AVFoundation` for audio, `Speech` for recognition, `ActivityKit` for Live Activities, and `Foundation` for networking.
- **Custom Networking Layer**: Instead of using third-party libraries like Alamofire or Moya, the project implements a custom `APIClient` actor (`FactShield/Core/Network/APIClient.swift`). This client handles HTTP requests, JSON serialization, and robust retry logic with exponential backoff using only `URLSession`.
- **Native AI Integration**: Interactions with Large Language Models (Qwen) are handled via direct HTTP calls to the DashScope API, encapsulated in `QwenAPI.swift`, avoiding specialized AI SDKs.

### Chrome Extension Dependency Strategy
- **Vanilla JavaScript**: The `FactShield-ChromeExtension` is built using vanilla JavaScript (ES Modules) without any frontend frameworks (e.g., React, Vue) or build tools (e.g., Webpack, Vite).
- **Manifest V3 Compliance**: Dependencies are limited to standard Chrome Extension APIs (`chrome.storage`, `chrome.sidePanel`, etc.) defined in `manifest.json`. 
- **Direct API Consumption**: The extension communicates directly with external services (Tavily, Google Fact Check, Qwen) via `fetch` API calls, managing API keys through `chrome.storage.local` rather than relying on backend proxy services or SDKs.

### Key Conventions
- **Standard Library First**: Developers are expected to leverage native Swift and JavaScript capabilities before considering any external integration.
- **Manual API Management**: API keys for third-party services (Qwen, Tavily, Google) are managed manually via user configuration (UserDefaults on iOS, Options page on Chrome) rather than through environment variable injection during a build step.
- **No Lockfiles**: Due to the absence of package managers, there are no `Package.resolved`, `Podfile.lock`, or `package-lock.json` files in the repository.