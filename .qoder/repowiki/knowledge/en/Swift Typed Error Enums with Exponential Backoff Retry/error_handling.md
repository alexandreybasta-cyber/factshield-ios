## Overview

The FactShield codebase employs a **typed enum-based error handling system** grounded in Swift's native `Error` and `LocalizedError` protocols, combined with **exponential backoff retry logic** for resilient network operations. Error handling is decentralized across domain-specific error types but follows consistent conventions throughout both the iOS app (Swift) and Chrome extension (JavaScript).

---

## Core Error Types

### App-Wide Domain Errors (`FactShieldError`)
Defined in `FactShield/FactShield/Models/Enums.swift`, this enum covers cross-cutting failure modes:
- `.audioSessionFailed(String)` — audio capture setup failures
- `.speechRecognitionUnavailable` / `.speechRecognitionDenied` — speech permission issues
- `.networkError(String)` — generic network failures
- `.apiKeyMissing` — configuration errors
- `.claimExtractionFailed(String)` — LLM parsing failures
- `.verdictSynthesisFailed(String)` — verdict generation failures
- `.liveActivityFailed(String)` — widget/Live Activity errors

All cases conform to `LocalizedError` and provide human-readable `errorDescription` strings.

### Network-Specific Errors (`APIError`)
Defined in `FactShield/FactShield/Core/Network/APIClient.swift`, this enum handles HTTP-level failures:
- `.invalidURL`, `.invalidResponse`, `.invalidJSON` — request/response format errors
- `.httpError(Int, String)` — non-2xx status codes with body text
- `.decodingError(String)` — JSON deserialization failures
- `.timeout` — request timeout
- `.noAPIKey` — missing credentials
- `.rateLimited(retryAfter: Int?)` — HTTP 429 with optional retry delay from headers

### Audio Session Errors (`AudioSessionError`)
Defined in `FactShield/FactShield/Core/Audio/AudioSessionManager.swift`:
- `.microphonePermissionDenied` — user denied or undetermined microphone access
- `.categoryConfigurationFailed(Error)` — wrapped underlying AVFoundation error
- `.activationFailed(Error)` — session activation failure with cause

Uses `CustomStringConvertible` instead of `LocalizedError` for description formatting.

### Synthesis Errors (`SynthesisError`)
Defined in `FactShield/FactShield/Core/Verification/VerdictSynthesisService.swift`:
- `.noContent` — empty API response
- `.invalidJSON` — malformed JSON from LLM
- `.invalidVerdictType(String)` — unrecognized verdict string

---

## Retry Strategy (Exponential Backoff)

The `APIClient` actor implements a **centralized retry mechanism** with exponential backoff:

```swift
private let maxRetries = 3
private let baseRetryDelay: TimeInterval = 1.0
```

**Retry triggers:**
- `.rateLimited` — uses server-provided `Retry-After` header if available, otherwise falls back to exponential delay
- `.httpError(code >= 500)` — server errors trigger retry with `baseRetryDelay * 2^attempt`
- `.timeout` — transient network timeouts are retried
- All other errors throw immediately without retry

**Backoff formula:** `delay = baseRetryDelay * pow(2, attempt)` producing delays of 1s, 2s, 4s across three attempts.

Both `request<T: Decodable>()` and `requestJSON()` methods share identical retry loops, ensuring consistency between typed and raw JSON responses.

---

## Error Propagation Patterns

### Async/Await with `throws`
All service-layer methods use Swift's async/await with typed throws:
- `ClaimExtractionService.extractClaims(from:) async throws -> [Claim]`
- `EvidenceRetrievalService.retrieveEvidence(for:) async throws -> [Evidence]`
- `VerdictSynthesisService.synthesizeVerdict(...) async throws -> Verdict`
- `AudioSessionManager.configureForCapture() async throws`

### Graceful Degradation via `do/catch` per Source
`EvidenceRetrievalService` demonstrates **parallel fault isolation**: each evidence source (Tavily, Google Fact Check, News) is called in its own `async let` and wrapped in individual `do/catch` blocks. A single source failure logs a warning but does not abort the entire retrieval:

```swift
do {
    let tavily = try await tavilyResults
    allEvidence.append(contentsOf: tavily)
} catch {
    logger.warning("Tavily search failed: \(error.localizedDescription)")
}
```

This ensures partial results are still usable when some providers fail.

### Coordinator-Level Error Suppression
`FactCheckCoordinator.extractAndVerify()` wraps the entire pipeline (extract → retrieve → synthesize) in a single `do/catch` that only logs the error:

```swift
catch {
    logger.error("Fact-check pipeline error: \(error)")
}
```

This prevents a single claim verification failure from crashing the continuous fact-checking session.

---

## Chrome Extension Error Handling (JavaScript)

The Chrome extension uses a simpler **try/catch + callback notification** pattern:

- `FactCheckPipeline.checkText()` wraps the full pipeline in try/catch, emitting `PIPELINE_STATES.ERROR` on failure
- Individual API calls in `pipeline.js` use `Promise.allSettled()` to isolate failures across Tavily and Google sources
- Background service worker message handlers return `{ error: message }` objects rather than throwing
- No retry logic is implemented in the JavaScript layer; retries are expected at the API client level

---

## Logging Integration

All errors are logged via the centralized `AppLogger` enum (`FactShield/FactShield/Utilities/Logger.swift`) using Apple's `OSLog` framework with subsystem-scoped loggers:
- `com.factshield.api` — network errors
- `com.factshield.audio` — audio session failures
- `com.factshield.claims` — extraction parse errors
- `com.factshield.verification` — evidence/verdict failures

Log levels used:
- `.error()` — unrecoverable failures (permission denied, invalid JSON)
- `.warning()` — transient failures that were handled (retry triggered, single source failure)
- `.info()` — successful recovery or normal operation state

---

## Developer Conventions

1. **Define domain-specific error enums** conforming to `Error` and `LocalizedError` (or `CustomStringConvertible` for internal types). Never throw raw `NSError` or generic `Error`.

2. **Wrap underlying errors** when re-throwing across abstraction boundaries (e.g., `AudioSessionError.categoryConfigurationFailed(error)` wraps the AVFoundation error).

3. **Use exponential backoff only for transient errors** (5xx, timeouts, rate limits). Client errors (4xx except 429) and validation errors should fail fast.

4. **Isolate parallel failures** using individual `do/catch` blocks or `Promise.allSettled()` so one failing provider doesn't block others.

5. **Log before throwing** at the point of detection; do not log again at the catch site unless adding context.

6. **Never use `try!` or `try?`** for critical operations where failure must be surfaced. The codebase avoids forced unwraps on throwing calls.

7. **Clean LLM JSON responses** defensively (strip markdown code fences) before decoding, with fallback parsers where possible.
