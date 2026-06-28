## Overview

FactShield uses Apple's **OSLog framework** (`import OSLog`) as its logging system. The application employs a decentralized approach where each service/module creates its own `Logger` instance with subsystem and category identifiers, rather than using the centralized `AppLogger` enum defined in `Utilities/Logger.swift`.

## Framework and Approach

- **Framework**: Apple's native `OSLog.Logger` from the `OSLog` module
- **Pattern**: Per-service logger instances created inline within each class/service
- **Centralized definition exists but unused**: `AppLogger` enum in `Utilities/Logger.swift` defines pre-configured loggers for all subsystems, but codebase does not reference it — each file instantiates its own `Logger` directly

## Key Files

- **`FactShield/FactShield/Utilities/Logger.swift`** — Defines `AppLogger` enum with static logger instances for all subsystems (currently unused)
- **`FactShield/FactShield/Core/Audio/AudioCaptureService.swift`** — Example of per-service logger pattern
- **`FactShield/FactShield/Core/Network/APIClient.swift`** — Demonstrates warning-level logging for retry logic
- **`FactShield/FactShield/Core/Claims/ClaimExtractionService.swift`** — Shows error-level logging for parsing failures
- **`FactShield/FactShield/BroadcastExtension/SampleHandler.swift`** — Broadcast extension logging

## Architecture and Conventions

### Subsystem and Category Structure

Loggers follow a consistent naming convention:
- **Subsystem format**: `com.factshield.<domain>` (e.g., `com.factshield.audio`, `com.factshield.api`, `com.factshield.claims`)
- **Category format**: Descriptive class or feature name (e.g., `AudioCapture`, `QwenAPI`, `ClaimExtraction`)

Defined subsystems:
| Subsystem | Categories |
|-----------|------------|
| `com.factshield.audio` | AudioCapture, AudioSession, BufferProcessor |
| `com.factshield.speech` | SpeechRecognition |
| `com.factshield.claims` | ClaimExtraction |
| `com.factshield.verification` | EvidenceRetrieval, VerdictSynthesis |
| `com.factshield.api` | QwenAPI, APIClient |
| `com.factshield.activity` | ActivityManager |
| `com.factshield.core` | FactCheckCoordinator |
| `com.factshield.broadcast` | SampleHandler |
| `com.factshield.app` | General |

### Log Levels Used

Three log levels are actively used across the codebase:

1. **`.info`** — Normal operational events:
   - Service lifecycle events (start/stop)
   - Successful operations (claims extracted, API requests sent)
   - Configuration confirmations (audio session setup)
   - Token usage metrics from API responses

2. **`.warning`** — Recoverable issues and retry scenarios:
   - Rate limiting events with retry delay
   - Server errors (5xx) with retry attempts
   - Timeout events with backoff timing
   - Missing API key configuration
   - Generic request failures during retry loops

3. **`.error`** — Failures requiring attention:
   - Audio engine startup failures
   - JSON parsing/decoding failures
   - Missing content in API responses
   - Fallback parsing failures

**Not used**: `.debug` and `.fault` levels are not present in the codebase.

### Logger Instance Pattern

Each service creates a private logger instance as a property:

```swift
private let logger = Logger(subsystem: "com.factshield.audio", category: "AudioCapture")
```

This is done in:
- Singleton services (`AudioCaptureService.shared`, `ClaimExtractionService.shared`)
- Actor-based services (`APIClient`)
- Extension handlers (`SampleHandler`)

### String Interpolation

Log messages use Swift string interpolation to include contextual data:
- Error descriptions: `"Failed to start audio engine: \(error)"`
- Counts and metrics: `"Extracted \(extracted.count) claims from transcript"`
- Retry state: `"Rate limited. Retrying after \(delay)s (attempt \(attempt + 1)/\(self.maxRetries))"`
- API parameters: `"model=\(model), messages=\(messages.count)"`

## Rules Developers Should Follow

1. **Use OSLog exclusively** — Do not use `print()` or other logging mechanisms; all logging goes through `Logger` from `OSLog`

2. **Follow subsystem naming convention** — Use `com.factshield.<domain>` for subsystem and a descriptive category name matching the class or feature

3. **Create logger as private property** — Each class should have its own `private let logger = Logger(...)` instance rather than sharing or using the `AppLogger` enum

4. **Use appropriate log levels**:
   - `.info` for normal operations and state changes
   - `.warning` for recoverable issues, retries, and configuration problems
   - `.error` for failures that break functionality

5. **Include contextual information** — Always interpolate relevant variables (counts, delays, error descriptions) into log messages for debugging

6. **Consider activating AppLogger** — The centralized `AppLogger` enum in `Utilities/Logger.swift` provides a single source of truth for all logger configurations; consider migrating to use it for consistency

7. **No debug-level logging** — The codebase does not use `.debug` level; if verbose logging is needed during development, use `.info` or add conditional compilation
