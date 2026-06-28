# Error Handling Architecture

## Overview

This codebase employs a **typed enum-based error handling system** in Swift, combined with **exponential backoff retry logic** for network operations. The approach leverages Swift's native `Error` and `LocalizedError` protocols to provide structured, descriptive error types across both iOS (Swift) and Chrome Extension (JavaScript) platforms.

---

## Core Error Types

### Swift Error Enums

All error types conform to both `Error` and `LocalizedError`, providing human-readable descriptions via `errorDescription`:

1. **`APIError`** (`Core/Network/APIClient.swift`) — Network-level errors:
   - `.invalidURL`, `.invalidResponse`, `.httpError(Int, String)`
   - `.invalidJSON`, `.decodingError(String)`, `.timeout`
   - `.noAPIKey`, `.rateLimited(retryAfter: Int?)`

2. **`FactShieldError`** (`Models/Enums.swift`) — App-level domain errors:
   - `.audioSessionFailed(String)`, `.speechRecognitionUnavailable`
   - `.speechRecognitionDenied`, `.networkError(String)`
   - `.apiKeyMissing`, `.claimExtractionFailed(String)`
   - `.verdictSynthesisFailed(String)`, `.liveActivityFailed(String)`

3. **`SynthesisError`** (`Core/Verification/VerdictSynthesisService.swift`) — Verdict parsing errors:
   - `.noContent`, `.invalidJSON`, `.invalidVerdictType(String)`

4. **`ActivityError`** (`Widgets/ActivityManager.swift`) — Live Activity errors:
   - `.notEnabled`, `.alreadyRunning`

### JavaScript Error Handling

The Chrome extension uses standard JavaScript `try/catch` blocks with `console.error` logging and status callback propagation. Errors are caught at pipeline boundaries and emitted as `PIPELINE_STATES.ERROR` events rather than throwing typed exceptions.

---

## Retry Strategy

### Exponential Backoff Implementation

The `APIClient` actor implements a sophisticated retry mechanism (`Core/Network/APIClient.swift`):

- **Max retries**: 3 attempts
- **Base delay**: 1.0 second
- **Backoff formula**: `baseRetryDelay * pow(2, attempt)` (1s → 2s → 4s)
- **Selective retry**: Only retries on specific error conditions:
  - `.rateLimited` — Uses server-provided `Retry-After` header if available
  - `.httpError(code >= 500)` — Server-side errors
  - `.timeout` — Network timeouts
  - All other errors are thrown immediately without retry

```swift
for attempt in 0..<maxRetries {
    do {
        let result = try await performRequest(...)
        return result
    } catch let error as APIError {
        switch error {
        case .rateLimited(let retryAfter):
            // Use server hint or exponential backoff
        case .httpError(let code, _) where code >= 500:
            // Exponential backoff
        case .timeout:
            // Exponential backoff
        default:
            throw error  // Non-retryable errors fail fast
        }
    }
}
```

Both `request<T: Decodable>()` and `requestJSON()` methods implement identical retry logic, ensuring consistency across typed and raw JSON responses.

---

## Error Propagation Patterns

### Async/Await with `throws`

Services use Swift's async/await pattern with explicit error propagation:

- **Throwing functions**: Services like `VerdictSynthesisService.synthesizeVerdict()` and `EvidenceRetrievalService.retrieveEvidence()` declare `async throws` signatures
- **Error transformation**: Lower-level errors are wrapped into domain-specific types (e.g., `APIError.decodingError` → `SynthesisError.invalidJSON`)
- **Graceful degradation**: When evidence retrieval fails, the coordinator falls back to model-only verdict synthesis

### Coordinator-Level Error Handling

The `FactCheckCoordinator` catches all pipeline errors at the top level (`Features/FactCheck/FactCheckCoordinator.swift:158-160`):

```swift
catch {
    logger.error("Fact-check pipeline error: \(error)")
}
```

Errors are logged but not propagated to the UI, preventing session crashes during periodic claim extraction cycles.

### Silent Failure with `try?`

Non-critical operations use `try?` to suppress errors:

- Audio session configuration/deactivation in view lifecycle
- Live Activity startup in navigation handlers
- These failures are logged internally but don't block user flows

---

## Integration with Logging

All error paths integrate with the centralized `OSLog` system (`Utilities/Logger.swift`):

- Each subsystem has a dedicated `Logger` instance (audio, speech, claims, verification, api, etc.)
- Retry attempts log warnings with context: `"Server error 500. Retrying after 2.0s (attempt 2/3)"`
- Final errors are logged before being thrown or caught
- Log categories enable filtering by subsystem in Console.app

---

## Design Conventions

### Rules for Developers

1. **Define typed errors per module**: Each service layer should define its own error enum conforming to `Error` and `LocalizedError`
2. **Provide descriptive messages**: Every error case must include a clear `errorDescription` with contextual details
3. **Use exponential backoff for transient failures**: Network errors (5xx, timeouts, rate limits) should retry; client errors (4xx) should fail fast
4. **Catch at orchestration boundaries**: Coordinators catch errors to prevent cascading failures; services propagate errors upward
5. **Log before throwing**: Always log error context before throwing to aid debugging
6. **Prefer `async throws` over completion handlers**: Use Swift concurrency for error propagation instead of callback-based error passing
7. **Use `try?` only for non-critical side effects**: Audio session setup, activity updates — never for core business logic

### Anti-Patterns to Avoid

- ❌ Do not use `fatalError` or force-unwraps in production paths
- ❌ Do not swallow errors silently without logging
- ❌ Do not retry on client errors (4xx) — these indicate bad requests
- ❌ Do not mix `Result` types with `async throws` — prefer the latter for consistency

---

## Key Files

- `FactShield/FactShield/Core/Network/APIClient.swift` — Retry logic and API error definitions
- `FactShield/FactShield/Models/Enums.swift` — Global app error enum
- `FactShield/FactShield/Core/Verification/VerdictSynthesisService.swift` — Domain-specific error handling
- `FactShield/FactShield/Widgets/ActivityManager.swift` — Activity error definitions
- `FactShield/FactShield/Features/FactCheck/FactCheckCoordinator.swift` — Top-level error catching
- `FactShield-ChromeExtension/src/api/pipeline.js` — JavaScript error propagation pattern