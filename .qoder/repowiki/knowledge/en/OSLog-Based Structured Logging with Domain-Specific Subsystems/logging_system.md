## Overview

The FactShield application uses Apple's **OSLog framework** (`import OSLog`) as its sole logging infrastructure. There is no third-party logging library; the system relies entirely on the standard library `Logger` type provided by Apple for iOS/macOS development.

## Architecture

### Centralized Logger Registry

A centralized enum `AppLogger` (located at `FactShield/Utilities/Logger.swift`) defines pre-configured static logger instances organized by functional domain:

- **Audio subsystem** (`com.factshield.audio`): AudioCapture, AudioSession, BufferProcessor
- **Speech subsystem** (`com.factshield.speech`): SpeechRecognition, TranscriptManager
- **Claims subsystem** (`com.factshield.claims`): ClaimExtraction
- **Verification subsystem** (`com.factshield.verification`): EvidenceRetrieval, VerdictSynthesis
- **API subsystem** (`com.factshield.api`): QwenAPI, APIClient, TavilySearch, GoogleFactCheck
- **Core subsystem** (`com.factshield.core`): FactCheckCoordinator
- **Activity subsystem** (`com.factshield.activity`): ActivityManager
- **Broadcast subsystem** (`com.factshield.broadcast`): SampleHandler
- **General** (`com.factshield.app`): General-purpose logging

Each logger instance follows the pattern:
```swift
Logger(subsystem: "com.factshield.<domain>", category: "<ComponentName>")
```

### Usage Pattern

Despite the existence of the `AppLogger` registry, most services instantiate their own private logger directly rather than referencing the shared enum:

```swift
private let logger = Logger(subsystem: "com.factshield.audio", category: "AudioCapture")
```

This pattern appears consistently across all service classes (e.g., `AudioCaptureService`, `QwenAPI`, `FactCheckCoordinator`, `SampleHandler`). The `AppLogger` enum exists but is not actively used in the codebase — it serves more as documentation of available logging domains.

## Log Levels

The codebase uses three log levels from OSLog:

1. **`.info`** — Normal operational events (session start/stop, API calls, state transitions)
2. **`.warning`** — Potential issues requiring attention (e.g., zero audio buffers received)
3. **`.error`** — Failures and exceptional conditions (permission denied, network errors, invalid responses)

No `.debug` level logging is present in the codebase.

## Structured Logging Conventions

### String Interpolation for Structured Fields

OSLog's native string interpolation is used to embed structured data into log messages:

```swift
logger.info("Audio capture started — format: \(recordingFormat.sampleRate)Hz, \(recordingFormat.channelCount)ch, bufferSize: 4096")
logger.error("Invalid input format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount)")
```

Key structured fields commonly logged:
- **Identifiers**: model names, component states
- **Metrics**: buffer counts, token usage, elapsed time
- **Diagnostics**: permission states, session configuration, routing information
- **Error context**: error descriptions via `\(error)`

### Multi-line Diagnostic Logging

For complex debugging scenarios, multi-line warning sequences are used to provide contextual diagnostics:

```swift
self.logger.warning("⚠️ ZERO audio buffers received after 1s — audio may not be flowing!")
self.logger.warning("  Session active: \(session.isOtherAudioPlaying), category: \(session.category.rawValue)")
self.logger.warning("  Input route: \(inputs)")
self.logger.warning("  Engine running: \(self.engine.isRunning), ...")
```

## Key Files

| File | Purpose |
|------|---------|
| `FactShield/FactShield/Utilities/Logger.swift` | Centralized `AppLogger` enum defining all logger instances |
| `FactShield/FactShield/Core/Audio/AudioCaptureService.swift` | Example of info/warning/error usage with structured fields |
| `FactShield/FactShield/Core/Network/QwenAPI.swift` | API-level logging with token usage metrics |
| `FactShield/FactShield/Features/FactCheck/FactCheckCoordinator.swift` | Orchestrator-level lifecycle logging |
| `FactShield/FactShield/BroadcastExtension/SampleHandler.swift` | Extension-scoped logging with separate subsystem |

## Developer Rules

1. **Use domain-specific subsystems**: Always use the appropriate `com.factshield.<domain>` subsystem matching your component's responsibility.
2. **Instantiate private loggers**: Create a `private let logger` property in each service/class rather than referencing `AppLogger`.
3. **Prefer `.info` for lifecycle events**: Log session starts, stops, and major state transitions at `.info` level.
4. **Use `.error` for failures**: All thrown errors, permission denials, and API failures should be logged at `.error`.
5. **Include structured context**: Embed relevant diagnostic values (IDs, counts, states) using OSLog string interpolation rather than concatenating strings.
6. **No debug logging**: The codebase does not use `.debug` level; reserve detailed troubleshooting for `.info` or conditional compilation if needed.
7. **Consistent naming**: Category names should match the class or service name (e.g., `"AudioCapture"` for `AudioCaptureService`).