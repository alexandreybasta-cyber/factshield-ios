## Overview

FactShield uses a **two-layer configuration system** that prioritizes environment variables for development/testing and falls back to `UserDefaults` (iOS) or `chrome.storage.local` (Chrome Extension) for user-managed runtime settings. There is no dedicated configuration file format (e.g., `.env`, `.yaml`, `.toml`) — all configuration is managed through platform-native storage mechanisms.

---

## Architecture & Layering Strategy

### iOS App (`FactShield/FactShield/`)

The iOS app implements a **priority-based layering pattern** for API keys:

1. **Environment Variables (highest priority)** — Read via `ProcessInfo.processInfo.environment["KEY_NAME"]`
2. **UserDefaults (fallback)** — Read via `UserDefaults.standard.string(forKey: "key_name")`

This pattern is applied consistently across three API providers:

| Provider | Env Var Key | UserDefaults Key | File |
|----------|-------------|------------------|------|
| Qwen | `QWEN_API_KEY` | `qwen_api_key` | `Core/Network/QwenAPI.swift:78-81` |
| Tavily | `TAVILY_API_KEY` | `tavily_api_key` | `Core/Network/SearchAPI.swift:41-42` |
| Google Fact Check | `GOOGLE_FACTCHECK_API_KEY` | `google_factcheck_api_key` | `Core/Network/SearchAPI.swift:113-114` |

**Settings UI**: The `SettingsView` uses SwiftUI's `@AppStorage` property wrapper, which automatically syncs with `UserDefaults`. This provides a unified read/write interface for user-facing configuration.

```swift
@AppStorage("qwen_api_key") private var qwenAPIKey: String = ""
@AppStorage("extraction_interval") private var extractionInterval: Double = 15.0
```

**Cross-process sharing**: The Broadcast Extension uses `UserDefaults(suiteName: Constants.appGroupIdentifier)` with the App Group identifier `"group.com.factshield.shared"` to share state (e.g., `isBroadcasting`, `broadcastStartedAt`) between the main app and the ReplayKit extension.

### Chrome Extension (`FactShield-ChromeExtension/`)

The Chrome Extension uses `chrome.storage.local` as its sole persistent configuration store. Configuration is managed through:

- **Options page** (`src/options/options.js`): Full settings UI for API keys and preferences
- **Shared constants** (`src/shared/constants.js`): Defines `STORAGE_KEYS` for consistent key naming
- **Background service worker** (`src/background/service-worker.js`): Reads config at runtime

Stored keys:
- `qwen_api_key`, `tavily_api_key`, `google_factcheck_api_key` — API credentials
- `factshield_settings` — Nested object containing `enableHighlights`, `showNotifications`, `autoStartYoutube`, `extractionInterval`, `evidenceDepth`
- `factshield_history` — Runtime data (claim history)

---

## Key Files

| File | Purpose |
|------|---------|
| `FactShield/FactShield/Core/Network/QwenAPI.swift` | Qwen API key resolution (env → UserDefaults) |
| `FactShield/FactShield/Core/Network/SearchAPI.swift` | Tavily & Google API key resolution (env → UserDefaults) |
| `FactShield/FactShield/Features/Settings/SettingsView.swift` | iOS settings UI using `@AppStorage` |
| `FactShield/FactShield/Utilities/Constants.swift` | Static constants (URLs, intervals, UserDefaults key names) |
| `FactShield/FactShield/Resources/Info.plist` | iOS permissions and background mode declarations |
| `FactShield-ChromeExtension/src/options/options.js` | Chrome Extension settings UI and `chrome.storage.local` management |
| `FactShield-ChromeExtension/src/shared/constants.js` | Shared constants including `STORAGE_KEYS` enum |
| `FactShield-ChromeExtension/manifest.json` | Extension permissions and host allowlist |

---

## Conventions & Developer Rules

### 1. API Key Resolution Pattern (iOS)
Always use the **environment-first, UserDefaults-fallback** pattern for sensitive keys:

```swift
private var apiKey: String {
    ProcessInfo.processInfo.environment["API_KEY_NAME"] ?? 
    UserDefaults.standard.string(forKey: "api_key_name") ?? ""
}
```

Do **not** hardcode API keys in source files. The codebase explicitly notes: *"in production use Keychain"* — the current approach is suitable for development but should migrate to Keychain for production releases.

### 2. UserDefaults Key Naming
- Use **snake_case** for UserDefaults keys (e.g., `qwen_api_key`, `extraction_interval`)
- Define key constants in `Constants.swift` when used across multiple files
- Use `@AppStorage` in SwiftUI views for automatic binding

### 3. Cross-Extension State Sharing (iOS)
When sharing state between the main app and Broadcast Extension:
- Use `UserDefaults(suiteName: Constants.appGroupIdentifier)` with the App Group ID
- Both targets must declare the same App Group in their entitlements

### 4. Chrome Extension Storage
- Always use `chrome.storage.local` (not `sync` or `session`) for persistence
- Wrap storage access in `try/catch` since it may fail outside extension context
- Use the `STORAGE_KEYS` constant object from `shared/constants.js` to avoid typos

### 5. Static Configuration
Non-user-configurable values (URLs, timeouts, thresholds) live in:
- `Constants.swift` (iOS)
- `shared/constants.js` (Chrome Extension)

These are compile-time constants, not runtime-configurable.

### 6. No `.env` File Support
The iOS app reads environment variables set at **process launch time** (e.g., via Xcode scheme environment variables or CI injection). There is no `.env` file parsing library. To configure locally:
- **Xcode**: Edit the scheme → Arguments → Environment Variables
- **CI/CD**: Set env vars in the build environment

---

## Security Notes

- API keys stored in `UserDefaults` are **not encrypted** — they are plaintext in the app sandbox
- The codebase acknowledges this limitation with the comment: *"in production use Keychain"*
- Chrome Extension stores keys in `chrome.storage.local`, which is scoped to the extension but also unencrypted at rest
- The `SecureInputField` component in SettingsView only masks input visually; it does not provide cryptographic protection