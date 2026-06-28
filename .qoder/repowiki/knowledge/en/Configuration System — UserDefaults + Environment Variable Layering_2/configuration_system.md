## Overview

FactShield uses a **two-tier configuration layering strategy** that prioritizes environment variables for development/testing and falls back to persistent user storage for runtime configuration. The system spans two platforms (iOS/macOS via Swift and Chrome Extension via JavaScript) with platform-specific storage mechanisms but consistent configuration semantics.

## Architecture & Approach

### iOS/macOS App (Swift)

The iOS app employs a **layered configuration resolution pattern**:

1. **Environment Variables (highest priority)** — Read via `ProcessInfo.processInfo.environment` for API keys during development or CI/CD scenarios
2. **UserDefaults (fallback/persistent)** — User-configured values stored via `@AppStorage` property wrappers in SwiftUI views and `UserDefaults.standard` in service classes

This pattern is implemented consistently across all three API providers:

```swift
// Pattern used in QwenAPI.swift, SearchAPI.swift
private var apiKey: String {
    ProcessInfo.processInfo.environment["QWEN_API_KEY"] ?? 
    UserDefaults.standard.string(forKey: "qwen_api_key") ?? ""
}
```

**Key design decisions:**
- Environment variables take precedence over UserDefaults, enabling developers to override user settings for testing without modifying persisted state
- Empty string fallback prevents nil crashes while signaling unconfigured state
- Comments explicitly note production should use Keychain instead of UserDefaults for secrets

### Chrome Extension (JavaScript)

The Chrome extension uses **chrome.storage.local** as its sole persistent storage mechanism:

- API keys and preferences are loaded asynchronously via `chrome.storage.local.get()`
- Settings are saved via `chrome.storage.local.set()` with validation
- No environment variable support (browser extensions lack this capability)
- Configuration is loaded at pipeline initialization time and cached in memory

## Key Configuration Categories

### API Keys (Secrets)
Three external API integrations require authentication:
- **Qwen API Key** (`qwen_api_key`) — Required; powers claim extraction and verdict synthesis
- **Tavily API Key** (`tavily_api_key`) — Optional; enhances web search evidence quality
- **Google Fact Check API Key** (`google_factcheck_api_key`) — Optional; cross-references Google's fact-check database

### Pipeline Parameters
- **Extraction Interval** (`extraction_interval`) — How often claims are extracted from transcript (5–60 seconds, default 15s)
- **Evidence Depth** (`evidenceDepth`) — Number of sources per claim: minimal (3), standard (5), deep (8)

### Feature Toggles
- **Capture Mode** (`preferred_capture_mode`) — Microphone (AEC) vs System Audio (ReplayKit)
- **On-Device Recognition** (`on_device_recognition`) — Prefer local speech recognition
- **Auto-Start Live Activity** (`auto_start_live_activity`) — Automatically launch Live Activity widget
- **Enable Highlights** (`enableHighlights`) — Inline claim highlighting on web pages
- **Show Notifications** (`showNotifications`) — Browser notifications for verdicts
- **Auto-Start YouTube** (`autoStartYoutube`) — Automatic monitoring on YouTube pages

### Runtime State Keys
- `isBroadcasting`, `broadcastStartedAt`, `lastSessionId` — Broadcast session tracking
- `factshield_history` — Claim verification history (Chrome extension only)

## Key Files

| File | Platform | Role |
|------|----------|------|
| `FactShield/FactShield/Utilities/Constants.swift` | iOS | Centralized constants including UserDefaults key definitions, API base URLs, pipeline defaults |
| `FactShield/FactShield/Core/Network/QwenAPI.swift` | iOS | API key resolution pattern (env → UserDefaults) for Qwen API |
| `FactShield/FactShield/Core/Network/SearchAPI.swift` | iOS | API key resolution pattern for Tavily and Google Fact Check providers |
| `FactShield/FactShield/Features/Settings/SettingsView.swift` | iOS | User-facing settings UI using `@AppStorage` property wrappers |
| `FactShield-ChromeExtension/src/shared/constants.js` | Chrome | Shared constants including STORAGE_KEYS enum for consistent key naming |
| `FactShield-ChromeExtension/src/options/options.js` | Chrome | Options page with load/save logic using chrome.storage.local |
| `FactShield-ChromeExtension/src/api/pipeline.js` | Chrome | Pipeline initialization that loads API keys from storage |

## Conventions & Developer Rules

### 1. Configuration Key Naming
- Use **snake_case** for all storage keys (e.g., `qwen_api_key`, not `qwenApiKey`)
- Define keys in centralized constants files (`Constants.swift`, `constants.js`) to avoid typos
- Chrome extension uses `STORAGE_KEYS` frozen object for type-safe access

### 2. API Key Handling
- **Never hardcode API keys** in source files
- iOS: Support both environment variables (dev) and UserDefaults (production)
- Chrome: Always use `chrome.storage.local`; no env var alternative exists
- Mark optional APIs gracefully — return empty arrays or skip provider if key is missing
- Production iOS builds should migrate to Keychain (noted in code comments)

### 3. Default Values
- Provide sensible defaults for all non-secret configuration
- Pipeline defaults are defined in `Constants.swift` (e.g., `claimExtractionInterval = 15.0`)
- Chrome extension defaults are set in `options.js` state object and applied when storage returns undefined

### 4. Validation
- Chrome extension validates Qwen API key before saving (required field)
- API key test functionality exists in Chrome options page (`testQwenKey()`)
- iOS SettingsView shows configuration status indicators (green checkmark / red X)

### 5. Storage Persistence Strategy
- iOS: `@AppStorage` property wrapper automatically syncs with UserDefaults and triggers SwiftUI view updates
- Chrome: Explicit `loadSettings()` / `saveSettings()` functions with async/await pattern
- Both platforms persist across app restarts

### 6. Cross-Platform Consistency
- Same configuration keys used across iOS and Chrome (e.g., `qwen_api_key` in both)
- Same default values (extraction interval: 15s, max sources: 5)
- Enables shared documentation and user expectations

## Limitations & Security Notes

- **iOS secrets in UserDefaults**: Currently stored in plaintext UserDefaults; production should use Keychain
- **No config file support**: Neither platform uses `.env`, `.yaml`, or `.json` config files — all configuration is programmatic or user-driven
- **No feature flag system**: Feature toggles are simple boolean UserDefaults values, not a dedicated feature flag framework
- **No remote configuration**: All settings are local; no server-side config overrides
