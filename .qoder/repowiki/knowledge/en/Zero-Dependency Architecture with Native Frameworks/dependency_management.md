## System Approach

The FactShield repository employs a **zero-dependency** strategy across both its iOS and Chrome Extension platforms, deliberately avoiding third-party libraries in favor of native platform capabilities.

### iOS (Swift) — Swift Package Manager with Empty Dependencies

- **Package Manager**: The project uses Swift Package Manager (SPM) as defined in `FactShield/Package.swift`. However, the `dependencies` array is explicitly empty (`[]`), confirming that no third-party libraries are declared or managed via SPM.
- **Networking**: Instead of popular third-party networking libraries like Alamofire, the project implements a custom, actor-based `APIClient` using `URLSession` and `async/await`. This client handles JSON serialization, error handling, and exponential backoff retries internally.
- **Concurrency & State**: The app leverages Apple's native `Combine` framework for reactive state management and `OSLog` for structured logging, avoiding external dependencies for these common concerns.
- **Imports**: All Swift files import only standard Apple frameworks: `Foundation`, `SwiftUI`, `AVFoundation`, `Speech`, `ReplayKit`, `OSLog`, and `Combine`. No third-party module imports exist.

### Chrome Extension — Vanilla JavaScript with ES Modules

- **No Package Manager**: The Chrome extension does not use npm, yarn, or any JavaScript package manager. There is no `package.json`, `node_modules`, or lockfile present.
- **Module System**: Uses native ES modules (`"type": "module"` in manifest.json) with relative imports between internal files (e.g., `import { extractClaims } from "./qwen.js"`).
- **API Integration**: Direct `fetch()` calls to external APIs (Qwen, Tavily, Google Fact Check) without HTTP client libraries.
- **State Management**: Uses `chrome.storage.local` for configuration persistence instead of external state management libraries.

## Key Files

- `FactShield/Package.swift`: Defines the Swift package structure with an empty dependency list, enforcing the zero-dependency constraint at the build level.
- `FactShield/FactShield/Core/Network/APIClient.swift`: A custom, robust networking layer implemented as a singleton `actor`, providing thread-safe access to a shared `URLSession`. Implements generic methods for both typed decoding (`Decodable`) and raw JSON dictionary responses, with built-in retry logic and exponential backoff.
- `FactShield/FactShield/Core/Network/QwenAPI.swift` & `SearchAPI.swift`: Service-specific API clients built on top of the custom `APIClient`, demonstrating protocol-oriented design for interchangeable search implementations.
- `FactShield-ChromeExtension/manifest.json`: Declares host permissions for external APIs but contains no dependency declarations.
- `FactShield-ChromeExtension/src/api/pipeline.js`: Orchestrates the fact-checking pipeline using direct imports from sibling modules, with no external library dependencies.

## Architecture and Conventions

### Self-Contained Network Layer (iOS)

The `APIClient` actor provides:
- Generic request methods supporting both `Decodable` types and raw `[String: Any]` JSON
- Automatic retry logic with exponential backoff for transient errors (5xx, timeouts, rate limits)
- Centralized error handling via a typed `APIError` enum
- Thread-safe singleton pattern via Swift actors

### Protocol-Oriented Search (iOS)

The `SearchAPI.swift` file defines a `SearchProvider` protocol, allowing for interchangeable search implementations (e.g., Tavily, Google Fact Check) while maintaining a consistent internal interface. This promotes testability and modularity without requiring a dependency injection framework.

### Environment-Based Configuration

API keys and sensitive configurations are retrieved from `ProcessInfo.processInfo.environment` or `UserDefaults` (iOS) and `chrome.storage.local` (Chrome extension), adhering to platform-standard security practices without needing external secrets management libraries.

### Parallel Evidence Gathering (Chrome Extension)

The `FactCheckPipeline` class uses `Promise.allSettled()` to gather evidence from multiple sources (Tavily, Google Fact Check) in parallel, demonstrating native async/await patterns without external orchestration libraries.

## Rules for Developers

1. **No Third-Party Libraries**: Do not add new dependencies to `Package.swift` unless absolutely necessary and approved. The project aims to minimize supply chain risk and build complexity by using native Apple frameworks.
2. **Use Native Networking**: All HTTP requests must go through the existing `APIClient` actor. Do not create ad-hoc `URLSession` instances; instead, extend the `APIClient` if new features (like multipart uploads) are needed.
3. **Standard Library First**: Prefer `Foundation`, `Combine`, and `OSLog` for common tasks. Avoid introducing external libraries for JSON parsing, logging, or dependency injection.
4. **Configuration Management**: Add new API endpoints or configuration values to `Constants.swift` or use environment variables for secrets. Do not hardcode URLs or keys in service files.
5. **Chrome Extension Purity**: Do not introduce npm dependencies or build tooling (webpack, babel, etc.). Use vanilla JavaScript with ES modules and native browser/extension APIs only.