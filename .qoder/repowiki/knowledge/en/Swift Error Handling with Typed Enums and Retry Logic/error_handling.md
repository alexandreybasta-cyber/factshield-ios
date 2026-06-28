## Overview

FactShield uses Swift's native `Error` protocol with typed enum-based error types, centralized logging via `OSLog`, and structured retry mechanisms for network operations. The codebase follows Swift conventions: errors are propagated using `async throws`, caught at coordinator/UI boundaries, and logged rather than presented to users directly.

## Error Type Hierarchy

### Domain-Specific Error Enums

The codebase defines multiple domain-specific error types conforming to both `Error` and `LocalizedError`:

1. **`APIError`** (`Core/Network/APIClient.swift`) — Network-layer errors:
   - `.invalidURL`, `.invalidResponse`, `.httpError(Int, String)`, `.invalidJSON`, `.decodingError(String)`, `.timeout`, `.noAPIKey`, `.rateLimited(retryAfter: Int?)`
   - Provides human-readable descriptions via `errorDescription`

2. **`FactShieldError`** (`Models/Enums.swift`) — App-level umbrella errors:
   - `.audioSessionFailed(String)`, `.speechRecognitionUnavailable`, `.speechRecognitionDenied`, `.networkError(String)`, `.apiKeyMissing`, `.claimExtractionFailed(String)`, `.verdictSynthesisFailed(String)`, `.liveActivityFailed(String)`
   - Used by `AppState` for UI error presentation

3. **`SynthesisError`** (`Core/Verification/VerdictSynthesisService.swift`) — Verdict synthesis failures:
   - `.noContent`, `.invalidJSON`, `.invalidVerdictType(String)`

### Error Propagation Pattern

- Services use `async throws` functions (e.g., `extractClaims(from:) async throws`, `synthesizeVerdict(...) async throws`)
- Errors bubble up to `FactCheckCoordinator.extractAndVerify()` where they are caught in a single `catch` block and logged
- No error re-throwing or wrapping between layers; each service throws its own domain-specific type

## Retry Strategy

### Exponential Backoff in APIClient

`APIClient` implements automatic retry with exponential backoff for transient failures:

- **Max retries**: 3 attempts
- **Retryable conditions**: HTTP 5xx errors, timeouts, rate limits (429)
- **Non-retryable**: Client errors (4xx except 429), invalid URLs, missing API keys — these throw immediately
- **Backoff formula**: `baseRetryDelay * pow(2, attempt)` where `baseRetryDelay = 1.0s`
- **Rate limit handling**: Respects `Retry-After` header if present, otherwise uses exponential backoff

Both `request<T>()` (typed decoding) and `requestJSON()` (raw JSON) share identical retry logic.

## Logging System

### Centralized OSLog Wrapper

`AppLogger` (`Utilities/Logger.swift`) provides subsystem-scoped loggers:

```swift
static let audio = Logger(subsystem: "com.factshield.audio", category: "AudioCapture")
static let api = Logger(subsystem: "com.factshield.api", category: "QwenAPI")
// ... one logger per module
```

Each service creates its own `Logger` instance (not always via `AppLogger`). Log levels used:
- `.info()` — Normal operational events (session start, extraction count)
- `.warning()` — Recoverable issues (rate limiting, retry attempts)
- `.error()` — Failures (decoding errors, recognition failures)

### Error Logging Convention

Errors are consistently logged before being thrown or after being caught:
```swift
logger.error("Failed to decode claims JSON: \(error.localizedDescription)")
throw FactShieldError.claimExtractionFailed("Could not parse API response as claims")
```

## Error Presentation

### AppState Error State

`AppState` maintains observable error state for UI consumption:
```swift
var lastError: FactShieldError?
var showError: Bool = false

func presentError(_ error: FactShieldError) { ... }
func clearError() { ... }
```

However, **the current implementation does not wire up error presentation** — `FactCheckCoordinator` catches errors silently (logs only), and `HomeView` does not display error alerts. This is a gap between error capture and user-facing presentation.

## Key Design Decisions

1. **No panic/recover**: Swift does not use panics; all failures are handled via `throw/catch`
2. **No middleware pattern**: Error handling is inline within each service; no centralized error middleware exists
3. **Graceful degradation**: When evidence retrieval returns empty results, `FactCheckCoordinator` falls back to model-only verdict synthesis instead of failing
4. **Silent failure in some paths**: `AudioCaptureService.startListening()` catches engine start errors and logs them without propagating; `SpeechRecognitionService` handles recognition errors by auto-restarting rather than throwing
5. **Protocol-based search providers**: `SearchProvider` protocol defines `search(query:maxResults:) async throws -> [SearchResult]`, enabling interchangeable providers (Tavily, Google Fact Check) with consistent error contracts

## Developer Conventions

- Define new error types as `enum` conforming to `Error, LocalizedError` with descriptive `errorDescription`
- Use `async throws` for fallible async operations
- Catch errors at the coordinator level; log with context-specific `Logger`
- For network calls, rely on `APIClient`'s built-in retry; do not implement duplicate retry logic
- Map low-level errors (e.g., `APIError`) to app-level errors (`FactShieldError`) when crossing module boundaries (currently inconsistent — some services throw `APIError` directly)
- Use `@discardableResult` for stop/cleanup methods that may fail but should not force callers to handle errors
