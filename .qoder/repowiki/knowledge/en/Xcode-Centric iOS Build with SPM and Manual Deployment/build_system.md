## Build System Overview

FactShield uses a **dual-project structure** for its iOS application, relying primarily on **Xcode** as the build orchestrator with **Swift Package Manager (SPM)** as a secondary packaging mechanism. The Chrome extension component uses a manifest-driven build with no formal build tooling.

---

## Primary Build Tool: Xcode

### Project Structure
The repository contains two parallel iOS project directories:
- `FactShield/` — Contains a standalone `Package.swift` (SPM) and source code organized by feature modules
- `Xcode/FactShield/` — Full Xcode project (`FactShield.xcodeproj`) with five targets:
  - `FactShield` — Main app target (iOS/macOS/visionOS)
  - `FactShieldTests` — Unit tests
  - `FactShieldUITests` — UI/integration tests
  - `BroadcastExtension` — ReplayKit broadcast upload extension for screen audio capture
  - `FactShieldWidgetsExtension` — WidgetKit + Live Activity extension for Dynamic Island

### Build Configuration
From `project.pbxproj`, key settings include:
- **Development Team**: `T3KX3F4LGB` (automatic code signing)
- **Deployment Targets**: iOS 18.5, macOS 15.5, visionOS 2.5
- **Swift Version**: 5.0 (compiler-level), tools version 5.9 in Package.swift
- **Build Configurations**: Debug (dwarf debug info, `-Onone` optimization) and Release (dwarf-with-dsym, wholemodule compilation)
- **File System Synchronized Groups**: Xcode 16+ feature that auto-discovers files from disk rather than requiring explicit file references

### Target Dependencies
- `FactShield` depends on both `BroadcastExtension` and `FactShieldWidgetsExtension` (embedded via "Embed Foundation Extensions" build phase)
- Test targets depend on the main app target via `TEST_HOST` configuration

### Entitlements & Capabilities
Each target has dedicated entitlements files:
- `FactShield.entitlements` — App groups (`group.com.factshield.shared`), microphone, speech recognition
- `BroadcastExtension.entitlements` / `FactShieldBroadcast.entitlements` — ReplayKit broadcast upload
- `FactShieldWidgetsExtension.entitlements` — WidgetKit access

---

## Swift Package Manager (SPM)

The `FactShield/Package.swift` defines a library product targeting iOS 17+ and macOS 14+, but declares **zero external dependencies**. This aligns with the documented "Zero-Dependency Architecture" — all networking uses `URLSession` directly, no third-party frameworks are pulled in.

The SPM package is likely used for:
1. Local development/testing outside Xcode
2. Potential future distribution as a reusable framework
3. Dependency resolution scaffolding (currently empty `dependencies: []`)

---

## Chrome Extension Build

The `FactShield-ChromeExtension/` directory uses a **manifest-driven approach** (Manifest V3):
- No build step or bundler (webpack, vite, etc.)
- Source files in `src/` are referenced directly by `manifest.json`
- Icons are pre-generated (PNG assets in `icons/`)
- Version: `1.0.0`, minimum Chrome version: 116

This is a **zero-build** architecture — developers load the unpacked extension directly from the source directory in Chrome's extension manager.

---

## Deployment Workflow

### iOS Deployment
No CI/CD pipeline exists. Deployment is manual via Xcode:
1. Archive via Xcode → Product → Archive
2. Distribute through App Store Connect or TestFlight
3. Code signing handled automatically via `DEVELOPMENT_TEAM = T3KX3F4LGB`

The `FactShield-iOS-BuildInstructions.md` (2100+ lines) serves as the authoritative deployment guide, covering:
- Project setup steps (capabilities, app groups, background modes)
- Phase-by-phase implementation guidance
- API key management (via environment variables or Keychain)

### GitHub Deployment Script
`push-via-api.sh` is a custom bash script that pushes the repository to GitHub via the REST API (not `git push`). It:
- Base64-encodes each tracked file and uploads as individual blobs
- Constructs a tree object and commit via API calls
- Updates the branch ref manually
- Includes retry logic for rate-limited API calls

**Security concern**: The script contains a hardcoded GitHub PAT token (lines 14), which should never be committed.

---

## Testing Strategy

Two test targets exist but contain minimal scaffolding:
- `FactShieldTests/FactShieldTests.swift` — Unit tests
- `FactShieldUITests/FactShieldUITests.swift` + `FactShieldUITestsLaunchTests.swift` — UI automation tests

No test runner configuration, coverage thresholds, or mock infrastructure is visible.

---

## Conventions & Developer Rules

1. **No external dependencies** — All networking, JSON parsing, and concurrency use Apple's standard library
2. **Xcode 16+ required** — Uses file-system-synchronized groups (new in Xcode 16)
3. **iOS 17+ minimum** — Required for AppIntents, interactive Dynamic Island buttons, and on-device speech recognition
4. **Manual build process** — No Makefile, no CI pipeline, no automated release flow
5. **Environment-based config** — API keys loaded via `ProcessInfo.processInfo.environment` or Keychain (TODO items in code)
6. **Dual project maintenance** — Changes must be mirrored between `FactShield/` and `Xcode/FactShield/FactShield/` directories (they contain duplicate source files)
