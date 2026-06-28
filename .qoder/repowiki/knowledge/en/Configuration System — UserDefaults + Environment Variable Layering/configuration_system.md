## Overview

FactShield uses a **two-layer configuration approach** combining `UserDefaults` (for user-managed settings) and environment variables via `ProcessInfo.processInfo.environment` (for secrets/developer overrides). There is no dedicated configuration framework, YAML/TOML files, or `.env` file parsing. Configuration is managed through:

1. **Hardcoded constants** (`Constants.swift`) for immutable app-level values
2. **`@AppStorage`-backed UserDefaults** for user-facing settings in SettingsView
3. **Environment variable fallbacks** for API keys (checked first, then fall back to UserDefaults)
4. **`Info.plist`** for iOS system permissions and background modes

---

## Key Files

| File | Purpose |
|------|---------|
| `FactShield/FactShield/Utilities/Constants.swift` | Static app-level constants (bundle IDs, API base URLs, audio parameters, pipeline intervals, UserDefaults key names) |
| `FactShield/FactShield/Features/Settings/SettingsView.swift` | User-facing settings UI; all mutable config persisted via `@AppStorage` to UserDefaults |
| `FactShield/FactShield/Core/Network/QwenAPI.swift` | Qwen API client; reads `QWEN_API_KEY` from env var or UserDefaults |
| `FactShield/FactShield/Core/Network/SearchAPI.swift` | Tavily and Google Fact Check providers; read respective API keys from env vars or UserDefaults |
| `FactShield/FactShield/Resources/Info.plist` | iOS permission descriptions, background modes, Siri intent declarations |
| `FactShield/FactShield/App/AppState.swift` | Runtime state holder (not persistent config, but observable app state) |

---

## Architecture & Conventions

### 1. Constants for Immutable Values

`Constants.swift` centralizes all compile-time configuration:
- App group identifier: `group.com.factshield.shared`
- Bundle IDs for main app and broadcast extension
- API base URL: `https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
- Audio defaults: sample rate (16000 Hz), buffer size (1024), max recording duration (5 min)
- Speech recognition limits: max transcript words (2000), recent window (75 words)
- Pipeline timing: claim extraction interval (15s), source count bounds (3–5)
- UserDefaults key strings (e.g., `"isBroadcasting"`, `"qwen_api_key"`)
- Notification names

This pattern avoids magic strings scattered across the codebase.

### 2. UserDefaults via `@AppStorage` for User Settings

All user-configurable settings live in `SettingsView` and use SwiftUI's `@AppStorage` property wrapper, which automatically persists to `UserDefaults.standard`. Configurable items include:

- **API Keys**: `qwen_api_key`, `tavily_api_key`, `google_factcheck_api_key` (stored as plain strings in SecureFields)
- **Audio preferences**: `preferred_capture_mode` ("microphone" or "replaykit"), `on_device_recognition` (Bool)
- **Pipeline tuning**: `extraction_interval` (Double, 5–60s slider)
- **Feature flags**: `auto_start_live_activity` (Bool)

The `@AppStorage` wrapper provides automatic two-way binding between UI and persistence.

### 3. Environment Variable Fallback for Secrets

API keys follow a **layered lookup pattern** in each network client:

```swift
private var apiKey: String {
    if let envKey = ProcessInfo.processInfo.environment["QWEN_API_KEY"], !envKey.isEmpty {
        return envKey
    }
    return UserDefaults.standard.string(forKey: "qwen_api_key") ?? ""
}
```

This same pattern is repeated in:
- `QwenAPI.swift` → `QWEN_API_KEY`
- `SearchAPI.swift` (Tavily) → `TAVILY_API_KEY`
- `SearchAPI.swift` (Google) → `GOOGLE_FACTCHECK_API_KEY`

**Priority order**: Environment variable > UserDefaults > empty string (which triggers `APIError.noAPIKey`).

This enables developers to inject secrets at runtime (e.g., via Xcode scheme environment variables or CI pipelines) without persisting them to disk.

### 4. Info.plist for System-Level Configuration

Standard iOS `Info.plist` entries cover:
- Permission usage descriptions (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`)
- Background modes: `audio`, `fetch`, `remote-notification`
- Siri shortcut intent types

No custom plist keys are defined beyond Apple's standard ones.

---

## Rules Developers Should Follow

1. **Add new immutable constants to `Constants.swift`** — never hardcode magic numbers, URLs, or key strings inline.

2. **Use `@AppStorage` for user-facing settings** — this ensures automatic persistence and UI reactivity. Define the UserDefaults key string in `Constants` to avoid typos.

3. **For API keys/secrets, implement the env-var-first fallback pattern** — check `ProcessInfo.processInfo.environment["KEY_NAME"]` first, then fall back to `UserDefaults.standard.string(forKey:)`. This supports both developer workflows (Xcode schemes) and production (user-entered keys).

4. **Do NOT commit API keys to source control** — the codebase explicitly notes "in production, use Keychain" in comments. Current storage in UserDefaults is plaintext; migration to Keychain is a known TODO.

5. **No external config files** — there are no `.yaml`, `.toml`, `.json`, or `.env` files parsed at runtime. All configuration is either compiled-in (Constants), user-set (UserDefaults), or injected via process environment.

6. **UserDefaults key naming convention** — snake_case with descriptive suffixes (e.g., `qwen_api_key`, `extraction_interval`, `auto_start_live_activity`). Always define the key string in `Constants` before using it.
