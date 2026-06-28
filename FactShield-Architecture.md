# FactShield — Live Fact-Checking Extension & iOS App

## Comprehensive Architecture Document

---

## Executive Summary

FactShield is a real-time fact-checking system delivered through two surfaces: a browser extension (Chrome/Edge/Firefox) and an iOS app with Dynamic Island integration. When a user encounters content on Instagram, X, YouTube, Spotify, or any live stream, a single click triggers a multi-layered verification pipeline that cross-references claims against live web searches, fact-check databases, and authoritative sources — producing a verdict in under 10 seconds with full source transparency.

The system does NOT rely on LLM training data for verification. Every claim is verified through live retrieval-augmented generation (RAG) with multi-source cross-checking. The LLM is used only for orchestration, claim extraction, and synthesis — never as the source of truth.

---

## Part 1: Fact-Checking Methodology

### The Five-Verdict Scale

Based on analysis of PolitiFact's Truth-O-Meter, Washington Post's Pinocchio Test, AFP's methodology, and Full Fact's approach, FactShield uses a five-tier verdict system:

| Verdict | Definition | Confidence Threshold |
|---------|-----------|---------------------|
| **TRUE** | The claim is accurate and supported by multiple authoritative sources | 90%+ agreement across sources |
| **SUBSTANTIALLY TRUE** | The claim is mostly correct but omits important context or contains minor inaccuracies | 70-89% agreement |
| **MISLEADING** | The claim contains elements of truth but is presented in a way that distorts reality | Mixed signals, significant context missing |
| **FALSE** | The claim is contradicted by authoritative evidence | 90%+ contradiction across sources |
| **UNVERIFIABLE** | Insufficient evidence to confirm or deny the claim | No clear consensus, or claims about future events/opinions |

### The Triple-Verification Pipeline

This is where FactShield differs from every existing tool. We implement what journalism organizations like PolitiFact, FactCheck.org, and AFP do manually — but algorithmically:

**Layer 1: Claim Extraction & Normalization**
- Speech-to-text transcribes the audio stream in real-time
- An LLM extracts atomic factual claims from the transcript (following the FEVERFact dataset methodology: each claim must be independently verifiable, decontextualized, and atomic)
- Claims are normalized: pronouns resolved, implicit references made explicit, temporal context added
- Check-worthiness classification filters out opinions, predictions, and value judgments (using a fine-tuned classifier inspired by Full Fact's BERT model)

**Layer 2: Multi-Source Evidence Retrieval**
- Each claim is converted into multiple search queries (not just one)
- Queries are sent to: (a) general web search, (b) Google Fact Check Tools API (ClaimReview database), (c) academic/scholarly sources, (d) news archives
- Evidence is temporally validated — only sources predating or contemporaneous with the claim are used (preventing "temporal leakage")
- Sources are deduplicated and ranked by: domain authority, recency, relevance, and IFCN compliance

**Layer 3: Cross-Checked Verdict Synthesis**
- The LLM acts as a Natural Language Inference (NLI) engine: for each piece of evidence, it determines whether it SUPPORTS, REFUTES, or is NEUTRAL toward the claim
- Multiple evidence pairs produce a voting matrix
- The final verdict is computed via weighted majority voting (higher-authority sources carry more weight)
- A confidence score is calculated from the agreement ratio
- A step-by-step reasoning chain is generated for full transparency

### Bias Mitigation Protocol

Based on research into cognitive biases in fact-checking (ScienceDirect, 2024) and IFCN Code of Principles:

1. **Multi-source requirement**: No verdict can be reached with fewer than 3 independent sources
2. **Source diversity enforcement**: The retrieval system deliberately queries sources across the political spectrum (tracked via Media Bias/Fact Check ratings)
3. **Temporal anchoring**: Evidence must predate the claim to prevent hindsight bias
4. **Claim-blind retrieval**: Search queries are generated from the claim itself, not from any assumed position
5. **Transparent reasoning**: Every verdict includes the full chain of evidence, source URLs, and the reasoning steps
6. **Dissent preservation**: If any credible source contradicts the majority verdict, it is explicitly surfaced in the output

---

## Part 2: Technology Stack

### AI Stack (Backend)

| Component | Recommended Technology | Rationale |
|-----------|----------------------|-----------|
| **Speech-to-Text** | `faster-whisper` (large-v3 or large-v3-turbo) via `WhisperLive` | 4x faster than openai/whisper, same accuracy. WhisperLive provides streaming. For iOS: SFSpeechRecognizer |
| **Claim Extraction LLM** | Qwen API (qwen-plus or qwen-max) with structured output | Cost-effective, strong multilingual, JSON mode. Fallback: GPT-4o-mini |
| **Check-worthiness Classifier** | Fine-tuned XLM-RoBERTa-Large (inspired by LiveFC) | Multilingual, fast, purpose-built for claim detection |
| **Evidence Retrieval** | LangChain + Tavily API + Google Fact Check API + SerpAPI | Multi-source RAG with ranked retrieval |
| **Verdict Synthesis** | Qwen API (qwen-max) with chain-of-thought prompting | Strong reasoning, structured JSON output, cost-effective |
| **Cross-encoder Ranking** | `cross-encoder/ms-marco-MiniLM-L-6-v2` (HuggingFace) | Ranks retrieved evidence by relevance to the claim |
| **Claim Matching** | LlamaIndex with vector store (Qdrant or ChromaDB) | Matches against previously verified claims database |
| **Vector Database** | Qdrant (self-hosted) or ChromaDB | Stores embeddings of verified claims for instant matching |
| **WebSocket Server** | FastAPI with WebSocket support | Real-time bidirectional communication with extension/app |
| **Caching** | Redis | Caches verified claims, search results, and session state |
| **Deployment** | Docker + Cloud Run / Railway / self-hosted VPS | Scalable, containerized |

### Frontend Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Extension Framework** | WXT + React + TypeScript | Best cross-browser support, Vite build, HMR |
| **Extension UI** | React + Tailwind CSS | Modern, fast to develop |
| **iOS App** | SwiftUI (native) | Required for ActivityKit, WidgetKit, AppIntents |
| **iOS Widgets** | WidgetKit + SwiftUI | Dynamic Island and Lock Screen views |
| **Backend API** | FastAPI (Python) | Async, WebSocket-native, ML ecosystem |
| **Database** | PostgreSQL + Redis | Relational data + caching |

### Open-Source Repos to Build On

| Repo | Stars | Use Case |
|------|-------|----------|
| [collabora/WhisperLive](https://github.com/collabora/WhisperLive) | 4.1k | Real-time streaming transcription |
| [SYSTRAN/faster-whisper](https://github.com/SYSTRAN/faster-whisper) | 23.9k | Fast STT engine (4x faster than openai/whisper) |
| [langchain-ai/langchain](https://github.com/langchain-ai/langchain) | 140k | RAG pipeline orchestration |
| [run-llama/llama_index](https://github.com/run-llama/llama_index) | 50.4k | Vector store + retrieval |
| [alandaitch/live-fact-checker](https://github.com/alandaitch/live-fact-checker) | 115 | Reference architecture for extension |
| [Cartus/Automated-Fact-Checking-Resources](https://github.com/Cartus/Automated-Fact-Checking-Resources) | 574 | Meta-resource: all papers/datasets/code |
| [MartinoMensio/claimreview-data](https://github.com/MartinoMensio/claimreview-data) | 7 | Auto-updated ClaimReview database |
| [awslabs/fever](https://github.com/awslabs/fever) | 127 | FEVER dataset (185K claims) |
| [shmsw25/factscore](https://github.com/shmsw25/factscore) | 444 | FActScore evaluation framework |
| [google-deepmind/long-form-factuality](https://github.com/google-deepmind/long-form-factuality) | 689 | SAFE evaluation (LongFact dataset) |
| [factiverse/FactAlign](https://github.com/factiverse/FactAlign) | 0 | LLM factuality alignment (EMNLP 2024) |

### APIs to Integrate

| API | Purpose | Cost |
|-----|---------|------|
| **Google Fact Check Tools API** | Search ClaimReview markup across all fact-checkers | Free (with quota) |
| **Tavily API** | AI-optimized web search for evidence retrieval | Free tier: 1000 searches/month |
| **SerpAPI** | Google Scholar + news search | $50/month for 5000 searches |
| **Media Bias/Fact Check API** | Source bias and reliability ratings | Free (scraping) |
| **NewsAPI** | Real-time news article search | Free tier: 100 requests/day |
| **Qwen API (DashScope)** | LLM for claim extraction + verdict synthesis | Pay-per-token |

---

## Part 3: Browser Extension Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BROWSER EXTENSION                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐    ┌──────────────────┐               │
│  │  Content Script   │    │  Side Panel UI   │               │
│  │  (per-tab)        │    │  (React + TS)    │               │
│  │                   │    │                  │               │
│  │  • DOM text       │    │  • Results feed  │               │
│  │    extraction     │    │  • Verdict cards │               │
│  │  • YouTube caption│    │  • Source links  │               │
│  │    capture        │    │  • Confidence    │               │
│  │  • Inline         │    │    meters        │               │
│  │    highlights     │    │  • Settings      │               │
│  │  • MutationObserver│   │  • Export        │               │
│  │  • MAIN world     │    │                  │               │
│  │    injection      │    │                  │               │
│  └────────┬─────────┘    └────────┬─────────┘               │
│           │                       │                          │
│           ▼                       ▼                          │
│  ┌──────────────────────────────────────────┐               │
│  │        Background Service Worker          │               │
│  │                                           │               │
│  │  • Message routing between components     │               │
│  │  • WebSocket connection management        │               │
│  │  • Tab lifecycle management               │               │
│  │  • State management (Zustand store)       │               │
│  │  • 20s keepalive ping for WebSocket       │               │
│  └────────────────┬─────────────────────────┘               │
│                   │                                          │
│           ┌───────┴───────┐                                  │
│           ▼               ▼                                  │
│  ┌────────────────┐  ┌────────────────┐                     │
│  │ Offscreen      │  │  WebSocket     │                     │
│  │ Document       │  │  Connection    │                     │
│  │                │  │  (to backend)  │                     │
│  │ • Audio capture│  │                │                     │
│  │   (tabCapture) │  │ • Real-time    │                     │
│  │ • Web Audio API│  │   verdict      │                     │
│  │ • Whisper.js   │  │   streaming    │                     │
│  │   (transformers│  │ • Status       │                     │
│  │    .js)        │  │   updates      │                     │
│  └────────────────┘  └────────────────┘                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ HTTPS / WSS
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND SERVER                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  WebSocket   │  │  REST API    │  │  Task Queue  │      │
│  │  Gateway     │  │  (FastAPI)   │  │  (Celery/RQ) │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                  │               │
│         ▼                 ▼                  ▼               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Fact-Checking Pipeline                    │  │
│  │                                                       │  │
│  │  1. Whisper STT (faster-whisper)                     │  │
│  │  2. Claim Extraction (Qwen API + structured output)  │  │
│  │  3. Check-worthiness Filter (XLM-RoBERTa)           │  │
│  │  4. Query Generation (Qwen API)                     │  │
│  │  5. Evidence Retrieval (LangChain RAG)              │  │
│  │     • Tavily web search                              │  │
│  │     • Google Fact Check API                          │  │
│  │     • SerpAPI (news + scholar)                       │  │
│  │     • Vector DB (previously verified claims)         │  │
│  │  6. Evidence Ranking (cross-encoder)                │  │
│  │  7. NLI Verdict Synthesis (Qwen API + CoT)         │  │
│  │  8. Weighted Majority Voting                        │  │
│  │  9. Reasoning Chain Generation                      │  │
│  │  10. Response Streaming via WebSocket               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  PostgreSQL  │  │  Redis       │  │  Qdrant      │      │
│  │  (claims,    │  │  (cache,     │  │  (vector     │      │
│  │   sessions)  │  │   sessions)  │  │   store)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Platform-Specific Capture Strategies

| Platform | Capture Method | Notes |
|----------|---------------|-------|
| **YouTube** | Extract closed captions via MAIN world injection + `ytInitialPlayerResponse` | Fastest path — no audio processing needed. Fallback to tabCapture + Whisper for videos without captions |
| **Instagram Reels** | `chrome.tabCapture.getMediaStreamId()` → offscreen document → Whisper | No caption API available. Capture audio, transcribe server-side |
| **X (Twitter)** | DOM text extraction (content script) + tabCapture for video audio | Text posts: extract directly. Video posts: capture audio |
| **Spotify (web)** | `chrome.tabCapture.getMediaStreamId()` → offscreen document → Whisper | Podcast audio must be captured and transcribed |
| **Live streams** | tabCapture + streaming Whisper + chunked claim extraction | Process in 10-second windows, extract claims from each window |
| **News articles** | DOM text extraction (content script) | No audio needed — extract article text directly |

### Manifest V3 Configuration

```json
{
  "manifest_version": 3,
  "name": "FactShield",
  "version": "1.0.0",
  "permissions": [
    "sidePanel",
    "tabCapture",
    "offscreen",
    "storage",
    "activeTab",
    "scripting"
  ],
  "host_permissions": [
    "https://api.factshield.app/*"
  ],
  "background": {
    "service_worker": "src/background/index.ts",
    "type": "module"
  },
  "side_panel": {
    "default_path": "src/sidepanel/index.html"
  },
  "action": {
    "default_icon": {
      "16": "icons/icon16.png",
      "48": "icons/icon48.png",
      "128": "icons/icon128.png"
    }
  },
  "content_scripts": [
    {
      "matches": [
        "*://*.youtube.com/*",
        "*://*.instagram.com/*",
        "*://*.x.com/*",
        "*://*.twitter.com/*",
        "*://open.spotify.com/*",
        "*://*.spotify.com/*"
      ],
      "js": ["src/content/index.ts"],
      "run_at": "document_idle"
    }
  ],
  "minimum_chrome_version": "116"
}
```

### Real-Time Communication Flow

```
User clicks "Fact Check" on extension icon
    │
    ▼
Content Script detects platform, captures text/audio
    │
    ├── [YouTube with captions] Extract caption text chunks
    ├── [Video/Audio] tabCapture → Offscreen → stream audio to backend
    └── [Article] Extract DOM text
    │
    ▼
Service Worker bundles data, sends via WebSocket to backend
    │
    ▼
Backend Pipeline executes (STT → Claims → Retrieval → Verdict)
    │
    ├── Stream status: "Transcribing..." → "Extracting claims..." → "Searching evidence..."
    │
    ▼
WebSocket pushes incremental updates to Service Worker
    │
    ├── Side Panel: Updates UI in real-time (verdict cards appear one by one)
    └── Content Script: Injects inline highlights on the page (color-coded by verdict)
```

### Agent Architecture for the Extension

Regarding your question about an agent living inside the extension — here is the analysis:

**Running a full agent inside the extension is NOT recommended.** Here is why:

1. **Manifest V3 service workers are ephemeral** — they get terminated after ~30 seconds of inactivity. An agent that needs to maintain state, run multi-step reasoning, and orchestrate tools would constantly lose its execution context.

2. **Memory constraints** — service workers have limited memory. Running an agent with tool-calling loops and context accumulation would hit limits quickly.

3. **API key exposure** — embedding API keys in the extension is a security disaster. Anyone can inspect installed extension source in seconds.

**The correct architecture is:**

- **Extension = thin client**: captures audio/text, displays results, manages UI
- **Backend = agent host**: runs the fact-checking agent with full tool access, state management, and API key security
- **Communication = WebSocket**: real-time bidirectional streaming of status and results

The backend agent (built with LangChain or LangGraph) has access to:
- Web search tools (Tavily, SerpAPI)
- Fact-check database tools (Google Fact Check API, ClaimReview)
- Vector search tools (Qdrant for previously verified claims)
- STT tools (faster-whisper)
- Reasoning tools (Qwen API with chain-of-thought)

If you want to use a cloud agent with API key, deploy the agent on your backend server (FastAPI + LangGraph) and have the extension communicate with it via WebSocket. The extension never holds the API key.

---

## Part 4: iOS Mobile App Architecture

### How Shazam Actually Works on iOS — And What It Means for Us

Understanding Shazam's architecture is essential because it proves the audio capture pattern works. After deep research, here is the technical reality:

**Two different Shazam entry points, two different mechanisms:**

1. **Control Center "Recognize Music" button** (privileged): Apple owns Shazam (acquired 2018) and integrated it as a first-party system component in iOS 14.2+. This module has privileged access to the Core Audio audio graph at a level below what `AVAudioSession` exposes to third-party apps. It taps the system audio output buffer before app-level mute is applied — which is why it can identify songs from muted videos. This API is NOT available to third-party developers.

2. **Standalone Shazam app** (microphone-based): The app uses `AVAudioEngine.inputNode` (microphone) with a buffer tap (size 2048), feeding PCM samples to `SHSession.matchStreamingBuffer()`. Apple's built-in Acoustic Echo Cancellation (AEC) and noise suppression clean up the mic input enough to identify music playing through the device's own speaker. When users report Shazam identifying songs from "muted" videos, they are typically using the Control Center button (privileged), not the standalone app.

**ShazamKit** (iOS 15+, public framework): This is the developer-accessible API. It can:
- Match audio against the Shazam catalog (millions of songs)
- Build **custom catalogs** (`SHCustomCatalog`) with your own reference audio signatures for local matching
- Generate compact audio fingerprints (`SHSignature`) from any audio buffer
- Work entirely offline with custom catalogs
- BUT: it relies entirely on audio buffers YOU provide — typically from the microphone. There is no system audio tap.

**The implication for FactShield:** We cannot replicate the Control Center Shazam's privileged system-level audio access. But we CAN replicate the standalone Shazam app's pattern: microphone-based capture with iOS's AEC handling the echo cancellation from the device's own speaker output. This is a proven, Apple-sanctioned pattern used by the most successful audio recognition app in history.

### Audio Capture: Two Modes

**Mode A: Microphone-Based Capture (Shazam-like, Primary)**

This is the frictionless one-tap experience:
- `AVAudioSession` configured with `.playAndRecord` category + `.mixWithOthers` option
- Instagram/YouTube/Spotify continue playing through the speaker
- `AVAudioEngine.inputNode` captures from the microphone
- iOS's built-in AEC suppresses the device's own speaker output from the mic recording
- Audio buffers are streamed to `SFSpeechRecognizer` for on-device transcription (or sent to backend for Whisper)
- User presses Action Button → app activates → Dynamic Island shows "Listening..." → user continues watching → press again to stop → verdict appears

Quality considerations: Works best in quiet environments. iOS's AEC is sophisticated enough that this pattern is production-proven at scale (Shazam, Voice Memos, all voice call apps). For speech content (podcasts, debates, news), transcription accuracy is high. For music-heavy content, accuracy degrades.

**Mode B: ReplayKit Broadcast Extension (High-Fidelity, Secondary)**

This captures the actual digital audio output from other apps — the ONLY sanctioned way for a third-party iOS app to do this:
- User starts a Screen Broadcast via Control Center → long-press Screen Recording → selects FactShield's broadcast extension
- iOS launches `RPBroadcastSampleHandler` in a separate process (~50MB memory limit)
- System delivers `.audioApp` buffers (uncompressed Linear PCM from the foreground app) via `processSampleBuffer(_:with:)`
- Extension extracts PCM audio and sends to backend via WebSocket (or writes to App Group shared container)
- Backend runs faster-whisper for high-fidelity transcription
- A persistent red bar/pill indicates recording is active

This mode gives pristine audio quality but has more friction (requires screen broadcast setup). It's ideal for: long-form content (podcasts, debates, documentaries), noisy environments, and when the user wants maximum accuracy.

### Entry Points

**Entry Point 1: Action Button Shortcut (Primary — Shazam-like)**

The user assigns FactShield's "Quick Fact-Check" Shortcut to their Action Button (iPhone 15 Pro+ and all iPhone 16 models). This is done via Settings > Action Button > Shortcut. The app exposes the shortcut through `AppShortcutsProvider` and `AppIntents`.

The flow:
1. User is watching Instagram/YouTube/Spotify
2. User presses Action Button → FactShield activates in listening mode (Mode A)
3. Live Activity starts → Dynamic Island shows "Listening..."
4. User continues watching content (audio plays through speaker, mic captures with AEC)
5. User presses Action Button again (or taps stop in app) → recording stops
6. Transcript is sent to backend → Dynamic Island updates: "Analyzing..." → "Verifying..." → verdict
7. User taps Dynamic Island to expand and see full verdict with sources

Implementation via AppIntents:
```swift
struct StartFactCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Fact-Check"
    static var description: IntentDescription = "Start listening and fact-checking audio from any app"
    
    func perform() async throws -> some IntentResult {
        // Start audio capture + Live Activity
        AudioCaptureService.shared.startListening()
        try await ActivityManager.shared.startLiveActivity()
        return .result()
    }
}

struct StopFactCheckIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Fact-Check"
    
    func perform() async throws -> some IntentResult {
        let transcript = AudioCaptureService.shared.stopListening()
        await NetworkService.shared.submitTranscript(transcript)
        return .result()
    }
}

struct FactShieldShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFactCheckIntent(),
            phrases: ["Start fact-checking with \(.applicationName)", "Fact-check this with \(.applicationName)"],
            shortTitle: "Fact-Check",
            systemImageName: "checkmark.shield"
        )
    }
}
```

**Entry Point 2: Control Center Widget (iOS 18)**

A `ControlWidgetButton` in Control Center that triggers the same `StartFactCheckIntent`. User swipes down Control Center, taps FactShield button, listening mode activates. This provides a system-level entry point alongside the Action Button.

**Entry Point 3: Share Extension (URL/Text-based)**

For content where URL-based verification is more efficient than audio capture (articles, text posts, tweets):
- User taps Share in any app → selects FactShield
- Extension captures URL/text/image
- Backend fetches page content, extracts text, runs fact-check pipeline
- Live Activity shows progress in Dynamic Island
- Works even for muted content or content without audio

**Entry Point 4: ReplayKit Broadcast (High-Fidelity Mode)**

For users who want maximum accuracy:
- User opens Control Center → long-presses Screen Recording → selects FactShield
- System audio from the current app is captured digitally
- Highest quality transcription, best for long-form content
- Red recording indicator visible (acceptable tradeoff for quality)

### Dynamic Island Design

The Dynamic Island shows status transitions (not streaming text) because iOS limits Live Activity refresh to every 5-15 seconds.

**Compact Leading (always visible when active):**
- Animated waveform icon while listening
- Status icon: magnifying glass (analyzing), checkmark (true), X (false), question mark (unverifiable), warning (misleading)

**Compact Trailing:**
- While listening: elapsed time "0:12"
- After verdict: confidence percentage "94%"

**Expanded (long-press the Dynamic Island):**
```
┌─────────────────────────────────────────────────┐
│  🎙️ Listening to Instagram              0:34    │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ ▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁  │   │
│  │         Live Audio Waveform              │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  [Stop Listening]              [Switch Mode]   │
└─────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────┐
│  🔍 Analyzing Claim                    3/5 src  │
│                                                 │
│  "The global temperature has risen 2°C          │
│   since pre-industrial times"                    │
│                                                 │
│  ━━━━━━━━━━━━━━━━━━━━░░░░░  78%                │
│                                                 │
│  Sources: NASA, IPCC, NOAA                      │
│  [More Details]                    [Dispute]    │
└─────────────────────────────────────────────────┘
```

**Lock Screen Banner:**
```
┌─────────────────────────────────────────────────┐
│  FactShield                         SUBSTANTIALLY │
│                                       TRUE       │
│  "Global temp risen 2°C since pre-industrial"   │
│  Sources: NASA, IPCC, NOAA • 78% confidence     │
└─────────────────────────────────────────────────┘
```

**Interactive Buttons (iOS 17+):**
- "More Sources" — opens app to full evidence view
- "Dispute" — flags the verdict for human review
- "Stop" — stops listening (while in listening mode)

### iOS Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      iOS APP (SwiftUI)                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │  Main App View   │  │  Share Extension  │                │
│  │                  │  │                   │                │
│  │  • Capture screen│  │  • URL capture    │                │
│  │  • History       │  │  • Text capture   │                │
│  │  • Settings      │  │  • Image capture  │                │
│  │  • Audio monitor │  │  • App Group      │                │
│  │                  │  │    storage        │                │
│  └────────┬─────────┘  └────────┬─────────┘                │
│           │                      │                          │
│           ▼                      ▼                          │
│  ┌──────────────────────────────────────────┐               │
│  │         Core Services Layer               │               │
│  │                                           │               │
│  │  • AudioCaptureService                    │               │
│  │    └─ Mode A: AVAudioEngine (mic + AEC)   │               │
│  │    └─ Mode B: ReplayKit (system audio)    │               │
│  │  • SpeechRecognizer (SFSpeechRecognizer)  │               │
│  │  • ShazamKitSession (audio fingerprinting)│               │
│  │  • NetworkService (URLSession + WebSocket)│               │
│  │  • ActivityManager (ActivityKit)          │               │
│  │  • AppIntentProvider                      │               │
│  │  • ClipboardMonitor                       │               │
│  └────────────────┬─────────────────────────┘               │
│                   │                                          │
│           ┌───────┴───────────────┐                          │
│           ▼                       ▼                          │
│  ┌──────────────────┐   ┌────────────────────┐             │
│  │ Widget Extension  │   │ Broadcast Upload   │             │
│  │                   │   │ Extension          │             │
│  │ • Control Center  │   │ (ReplayKit)        │             │
│  │   widget          │   │                    │             │
│  │ • Lock Screen     │   │ • Captures         │             │
│  │   widget          │   │   .audioApp PCM    │             │
│  │ • Dynamic Island  │   │   buffers from     │             │
│  │   (Live Activity) │   │   other apps       │             │
│  │   Compact         │   │ • Writes to App    │             │
│  │   Expanded        │   │   Group container  │             │
│  │   Minimal         │   │ • ~50MB memory     │             │
│  │   Lock Screen     │   │   limit            │             │
│  └──────────────────┘   └────────────────────┘             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ HTTPS / WSS / APNs
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     BACKEND SERVER                           │
│                  (same as extension backend)                  │
│                                                              │
│  • APNs Push-to-Start: server initiates Live Activity       │
│  • APNs Push Updates: server updates Dynamic Island status  │
│  • APNs Push-to-End: server ends Live Activity with verdict │
│  • Same fact-checking pipeline as extension                 │
│  • Receives audio via WebSocket (Mode B) or text (Mode A)   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Live Activity Data Model (Swift)

```swift
import ActivityKit
import WidgetKit
import SwiftUI

struct FactCheckAttributes: ActivityAttributes {
    // Static data — set once when activity starts
    var captureMode: CaptureMode      // .microphone or .replayKit
    var sourceApp: String?            // "Instagram", "YouTube", "Spotify" (if known)
    var startedAt: Date
    
    public struct ContentState: Codable, Hashable {
        // Dynamic data — updated via APNs push or local updates
        var status: VerificationStatus
        var verdict: VerdictType?
        var confidenceScore: Double     // 0.0 - 1.0
        var sourceCount: Int
        var topSources: [String]        // ["NASA", "IPCC", "NOAA"]
        var reasoningSummary: String?
        var claimText: String?          // The claim being verified (set after extraction)
        var elapsedSeconds: Int         // Listening duration
        var updatedAt: Date
    }
    
    enum CaptureMode: String, Codable, Hashable {
        case microphone = "Microphone"
        case replayKit = "System Audio"
    }
    
    enum VerificationStatus: String, Codable, Hashable {
        case listening = "Listening..."
        case transcribing = "Transcribing..."
        case extracting = "Extracting claims..."
        case searching = "Searching evidence..."
        case verifying = "Cross-checking..."
        case complete = "Complete"
    }
    
    enum VerdictType: String, Codable, Hashable {
        case `true` = "TRUE"
        case substantiallyTrue = "SUBSTANTIALLY TRUE"
        case misleading = "MISLEADING"
        case `false` = "FALSE"
        case unverifiable = "UNVERIFIABLE"
    }
}
```

### The Complete iOS User Flow

**Scenario: User watching an Instagram Reel making political claims**

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User watching Instagram Reel                              │
│    Content: Politician making claims about economy          │
│                                                              │
│ 2. User presses Action Button                                │
│    → StartFactCheckIntent fires                              │
│    → AudioCaptureService starts (Mode A: mic + AEC)         │
│    → Live Activity begins                                    │
│    Dynamic Island: 🎙️ "Listening..." | 0:00                 │
│                                                              │
│ 3. User continues watching (10-30 seconds)                   │
│    Instagram audio plays through speaker                     │
│    Mic captures with AEC suppressing speaker output          │
│    SFSpeechRecognizer transcribes in real-time               │
│    Dynamic Island: 🎙️ "Listening..." | 0:23                 │
│                                                              │
│ 4. User presses Action Button again (or taps Stop)           │
│    → Audio capture stops                                     │
│    → Full transcript sent to backend via HTTPS               │
│    Dynamic Island: 🔍 "Analyzing..." | 23s                  │
│                                                              │
│ 5. Backend pipeline executes (8-12 seconds)                  │
│    → Claim extraction (Qwen API)                             │
│    → Evidence retrieval (Tavily + Google Fact Check)         │
│    → NLI verdict synthesis                                   │
│    → APNs push updates at each stage                        │
│    Dynamic Island: 🔍 "Cross-checking..." | 3/5 src         │
│                                                              │
│ 6. Verdict delivered                                         │
│    Dynamic Island compact: ✓ "SUBSTANTIALLY TRUE" | 87%     │
│    User long-presses → expanded view:                        │
│    ┌───────────────────────────────────────────┐            │
│    │ Claim: "Unemployment dropped to 3.5%"     │            │
│    │                                           │            │
│    │ Sources: BLS, World Bank, OECD            │            │
│    │ Confidence: 87%                           │            │
│    │                                           │            │
│    │ Reasoning: The 3.5% figure is accurate    │            │
│    │ for Q1 2026 per BLS data, but omits that  │            │
│    │ labor force participation also dropped.    │            │
│    │                                           │            │
│    │ [Open Full Report]        [Dispute]       │            │
│    └───────────────────────────────────────────┘            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Swift vs React Native Decision

**Recommendation: Native SwiftUI**

The iOS app requires deep integration with: ActivityKit (Live Activities), WidgetKit (Dynamic Island + Lock Screen + Control Center), AppIntents (Action Button + Siri), Share Extensions, AVAudioEngine with AEC, SFSpeechRecognizer, ReplayKit Broadcast Upload Extension, ShazamKit, and APNs token management.

With React Native, you would write ~50-60% native Swift code anyway, plus deal with bridging overhead, immature RN libraries for ActivityKit, and delayed access to new iOS features. For an app this native-API-heavy, SwiftUI is the clear choice.

If you later need an Android version, use Kotlin with Jetpack Compose — not React Native — to maintain first-class platform integration on both sides.

---

## Part 5: Backend Pipeline — Detailed Implementation

### The Fact-Checking Agent (LangGraph)

The backend runs a LangGraph state machine that orchestrates the entire pipeline. This is the "agent" — it lives on the server, not in the extension.

```
State Graph:
┌─────────────┐
│   START     │
└──────┬──────┘
       ▼
┌─────────────┐
│  Transcribe │ ← faster-whisper (if audio input)
└──────┬──────┘
       ▼
┌─────────────┐
│ Extract     │ ← Qwen API: extract atomic claims from text
│ Claims      │    Structured JSON output: [{claim, context, speaker}]
└──────┬──────┘
       ▼
┌─────────────┐
│ Filter      │ ← XLM-RoBERTa: is each claim check-worthy?
│ Claims      │    Removes opinions, predictions, value judgments
└──────┬──────┘
       ▼
┌─────────────┐
│ Match       │ ← LlamaIndex + Qdrant: has this claim been verified before?
│ Existing    │    If match found with high confidence → skip to verdict
└──────┬──────┘
       ▼
┌─────────────┐
│ Generate    │ ← Qwen API: convert each claim into 3-5 search queries
│ Queries     │    Variations: exact, paraphrased, negated, question form
└──────┬──────┘
       ▼
┌─────────────┐
│ Retrieve    │ ← LangChain: parallel search across:
│ Evidence    │    • Tavily (web search)
│             │    • Google Fact Check API (ClaimReview)
│             │    • SerpAPI (news + scholar)
│             │    • Qdrant (vector similarity to known facts)
└──────┬──────┘
       ▼
┌─────────────┐
│ Rank        │ ← cross-encoder/ms-marco: score each evidence piece
│ Evidence    │    by relevance to the claim
└──────┬──────┘
       ▼
┌─────────────┐
│ NLI         │ ← Qwen API: for each evidence piece, determine:
│ Evaluation  │    SUPPORTS / REFUTES / NEUTRAL
│             │    Produce step-by-step reasoning chain
└──────┬──────┘
       ▼
┌─────────────┐
│ Weighted    │ ← Aggregate NLI results with source authority weights
│ Majority    │    Calculate confidence score
│ Vote        │    Determine final verdict
└──────┬──────┘
       ▼
┌─────────────┐
│ Generate    │ ← Qwen API: produce human-readable explanation
│ Explanation │    with source citations and reasoning chain
└──────┬──────┘
       ▼
┌─────────────┐
│   END       │ ← Stream verdict + explanation to client
└─────────────┘
```

### Example Backend Response (JSON)

```json
{
  "session_id": "fc_20260627_abc123",
  "claims": [
    {
      "id": "claim_1",
      "original_text": "The global temperature has risen 2 degrees Celsius since pre-industrial times",
      "normalized": "Global average surface temperature has increased by 2°C compared to the 1850-1900 baseline",
      "check_worthy": true,
      "verdict": "SUBSTANTIALLY TRUE",
      "confidence": 0.87,
      "evidence": [
        {
          "source": "IPCC AR6 Synthesis Report (2023)",
          "url": "https://www.ipcc.ch/report/ar6/syr/",
          "authority": 0.98,
          "stance": "SUPPORTS",
          "snippet": "Global surface temperature has increased by 1.1°C [0.95°C to 1.20°C] since 1850-1900...",
          "temporal_valid": true
        },
        {
          "source": "NASA GISS Surface Temperature Analysis",
          "url": "https://data.giss.nasa.gov/gistemp/",
          "authority": 0.95,
          "stance": "PARTIALLY SUPPORTS",
          "snippet": "The planet's average surface temperature has risen about 1.1°C since the late 19th century...",
          "temporal_valid": true
        },
        {
          "source": "NOAA Global Climate Report",
          "url": "https://www.ncei.noaa.gov/access/monitoring/monthly-report/global/202413",
          "authority": 0.93,
          "stance": "REFUTES",
          "snippet": "The 2°C threshold has not yet been reached; current warming is approximately 1.2°C above pre-industrial levels",
          "temporal_valid": true
        }
      ],
      "reasoning": "The claim states a 2°C rise, but authoritative sources (IPCC, NASA, NOAA) consistently report approximately 1.1-1.2°C of warming since pre-industrial times. The 2°C figure is approximately double the actual measured increase. However, the claim correctly identifies that significant warming has occurred. The verdict is SUBSTANTIALLY TRUE in spirit (warming is real and significant) but the specific 2°C figure is an overstatement based on current data.",
      "source_agreement_ratio": 0.67,
      "sources_consulted": 5,
      "dissenting_sources": ["NOAA (refutes specific 2°C figure)"]
    }
  ],
  "metadata": {
    "processing_time_ms": 4200,
    "transcription_provider": "faster-whisper-large-v3",
    "llm_provider": "qwen-max",
    "search_providers": ["tavily", "google_factcheck", "serpapi"],
    "total_sources_consulted": 12,
    "timestamp": "2026-06-27T14:32:00Z"
  }
}
```

---

## Part 6: Performance Targets

| Metric | Target | How |
|--------|--------|-----|
| **Time to first status update** | < 500ms | Immediate WebSocket ack + status push |
| **Transcription latency** | < 2s per chunk | faster-whisper with streaming, 5-second audio chunks |
| **Claim extraction** | < 1s | Qwen API with structured output (JSON mode) |
| **Evidence retrieval** | < 3s | Parallel search across 4 sources, async HTTP |
| **Total pipeline (text input)** | < 8s | No transcription needed, skip to claim extraction |
| **Total pipeline (audio input)** | < 12s | Transcription + full pipeline |
| **Dynamic Island update latency** | < 2s from backend push | APNs high-priority push |
| **Concurrent sessions** | 100+ | FastAPI async + Redis session store |

---

## Part 7: Project Structure

### Monorepo Layout

```
factshield/
├── extension/                    # Browser extension (WXT + React + TS)
│   ├── src/
│   │   ├── background/           # Service worker
│   │   │   ├── index.ts
│   │   │   ├── websocket.ts
│   │   │   └── state.ts
│   │   ├── content/              # Content scripts (per-platform)
│   │   │   ├── index.ts
│   │   │   ├── youtube.ts
│   │   │   ├── instagram.ts
│   │   │   ├── twitter.ts
│   │   │   └── spotify.ts
│   │   ├── sidepanel/            # Side panel UI
│   │   │   ├── App.tsx
│   │   │   ├── components/
│   │   │   │   ├── VerdictCard.tsx
│   │   │   │   ├── SourceList.tsx
│   │   │   │   ├── ConfidenceMeter.tsx
│   │   │   │   └── ReasoningChain.tsx
│   │   │   └── hooks/
│   │   │       └── useWebSocket.ts
│   │   ├── offscreen/            # Offscreen document (audio)
│   │   │   ├── index.ts
│   │   │   └── audioCapture.ts
│   │   └── shared/               # Shared types and utilities
│   │       ├── types.ts
│   │       └── constants.ts
│   ├── wxt.config.ts
│   ├── package.json
│   └── tsconfig.json
│
├── ios/                          # iOS app (SwiftUI)
│   ├── FactShield/
│   │   ├── App/
│   │   │   └── FactShieldApp.swift
│   │   ├── Views/
│   │   │   ├── CaptureView.swift
│   │   │   ├── HistoryView.swift
│   │   │   └── SettingsView.swift
│   │   ├── Services/
│   │   │   ├── AudioRecorder.swift
│   │   │   ├── SpeechRecognizer.swift
│   │   │   ├── NetworkService.swift
│   │   │   └── ActivityManager.swift
│   │   ├── Intents/
│   │   │   └── FactCheckIntent.swift
│   │   └── Models/
│   │       └── FactCheck.swift
│   ├── FactShieldWidget/
│   │   ├── FactCheckWidget.swift
│   │   └── FactCheckLiveActivity.swift
│   ├── FactShieldShareExtension/
│   │   └── ShareViewController.swift
│   └── FactShield.xcodeproj
│
├── backend/                      # Backend server (FastAPI + Python)
│   ├── app/
│   │   ├── main.py               # FastAPI app + WebSocket endpoint
│   │   ├── config.py             # Settings (API keys, model config)
│   │   ├── models/
│   │   │   ├── claim.py          # Claim data models
│   │   │   ├── verdict.py        # Verdict data models
│   │   │   └── evidence.py       # Evidence data models
│   │   ├── pipeline/
│   │   │   ├── graph.py          # LangGraph state machine
│   │   │   ├── transcription.py  # faster-whisper integration
│   │   │   ├── claim_extraction.py  # Qwen API calls
│   │   │   ├── check_worthiness.py  # XLM-RoBERTa classifier
│   │   │   ├── retrieval.py      # LangChain RAG (multi-source)
│   │   │   ├── ranking.py        # Cross-encoder evidence ranking
│   │   │   ├── verification.py   # NLI verdict synthesis
│   │   │   └── voting.py         # Weighted majority voting
│   │   ├── tools/
│   │   │   ├── web_search.py     # Tavily integration
│   │   │   ├── factcheck_api.py  # Google Fact Check API
│   │   │   ├── news_search.py    # SerpAPI integration
│   │   │   └── vector_search.py  # Qdrant integration
│   │   ├── services/
│   │   │   ├── apns.py           # Apple Push Notification Service
│   │   │   ├── session.py        # Session management (Redis)
│   │   │   └── cache.py          # Caching layer
│   │   └── db/
│   │       ├── database.py       # PostgreSQL connection
│   │       └── migrations/       # Alembic migrations
│   ├── tests/
│   │   ├── test_pipeline.py
│   │   ├── test_retrieval.py
│   │   └── test_verdict.py
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── requirements.txt
│   └── pyproject.toml
│
├── shared/                       # Shared schemas and types
│   ├── api-schema.yaml           # OpenAPI specification
│   └── verdict-types.ts          # TypeScript types (copied to extension)
│
├── docs/
│   ├── ARCHITECTURE.md           # This document
│   ├── API.md                    # API documentation
│   └── DEPLOYMENT.md             # Deployment guide
│
├── scripts/
│   ├── setup.sh                  # Development setup
│   └── deploy.sh                 # Deployment script
│
└── README.md
```

---

## Part 8: Getting Started — Development Roadmap

### Phase 1: Backend Pipeline (Week 1-3)
1. Set up FastAPI project with WebSocket endpoint
2. Integrate faster-whisper for transcription
3. Build claim extraction with Qwen API (structured output)
4. Implement multi-source evidence retrieval (LangChain + Tavily + Google Fact Check)
5. Build NLI verdict synthesis with chain-of-thought
6. Implement weighted majority voting
7. Test end-to-end pipeline with sample claims
8. Set up Redis caching and Qdrant vector store

### Phase 2: Browser Extension (Week 3-5)
1. Set up WXT project with React + TypeScript
2. Build content scripts for YouTube (caption extraction)
3. Build tabCapture + offscreen document for audio platforms
4. Implement side panel UI with verdict cards
5. Connect extension to backend via WebSocket
6. Add inline page highlights (color-coded by verdict)
7. Test across Chrome, Edge, Firefox

### Phase 3: iOS App (Week 5-8)
1. Set up SwiftUI project with ActivityKit
2. Implement AudioCaptureService (Mode A: AVAudioEngine + AEC for mic-based capture)
3. Build Broadcast Upload Extension (Mode B: ReplayKit for high-fidelity system audio)
4. Implement Live Activity with Dynamic Island layouts (listening + verdict states)
5. Build AppIntents for Action Button and Siri ("Quick Fact-Check" shortcut)
6. Add Control Center widget (iOS 18)
7. Build Share Extension for URL/text capture
8. Implement APNs push integration (Push-to-Start, updates, Push-to-End)
9. Integrate SFSpeechRecognizer for on-device transcription
10. Test on iPhone 15 Pro+ (Action Button) and earlier models

### Phase 4: Polish & Launch (Week 8-10)
1. Performance optimization (caching, parallel retrieval)
2. Bias testing across political spectrum
3. Security audit (API key handling, data privacy)
4. Chrome Web Store submission
5. App Store submission
6. Landing page and documentation

---

## Key Technical Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| LLM hallucination in verdict synthesis | Wrong verdict | Triple-verification pipeline; LLM never decides alone — only synthesizes evidence from live retrieval |
| Mic-based audio capture quality | Degraded transcription in noisy environments | iOS AEC handles speaker echo (Shazam-proven pattern); ReplayKit broadcast mode available for high-fidelity capture; manual text input as ultimate fallback |
| Dynamic Island refresh rate (5-15s) | Delayed status updates | Design status transitions (not streaming text); use local countdown timers for time-sensitive UI |
| API cost at scale | High per-query cost | Cache verified claims aggressively; match against cache before running full pipeline |
| Service worker termination | WebSocket drops | 20s keepalive ping; offscreen document WebSocket as fallback; auto-reconnect with backoff |
| Source bias in retrieval | Biased verdicts | Multi-source requirement; source diversity enforcement; Media Bias/Fact Check integration |
| Whisper accuracy on accented speech | Wrong transcription | Use large-v3 model; add custom vocabulary; offer manual text input as fallback |

---

## Part 8: Competitive Landscape — Existing Live Fact-Checking Tools

The "live fact-checking while watching" space is surprisingly small. Only a handful of tools do real-time audio-to-verdict pipelines on live content. Everything else operates on text you highlight or articles you're reading.

### Direct Competitors (Real-Time Audio/Video Fact-Checking)

**InTruth**
- Chrome extension; works on YouTube live debates, interviews, press conferences
- Uses Perplexity Sonar for web search + Claude (Anthropic) for verdict synthesis
- User supplies their own API key
- Closed source; gained significant viral traction on LinkedIn/X
- Key differentiator: Built specifically for live debates by a university student
- Limitation: No cross-verification pipeline; single LLM verdict without multi-source voting

**Facticity AI (a.k.a. live-fact-checker)**
- Chrome/Edge extension; works on YouTube live streams + pre-recorded videos
- Named one of TIME's 200 Best Inventions of 2024
- Uses Gemini 2.0 Flash for claim identification + grounded web search for verification
- Three transcription modes: YouTube captions, browser tab audio capture, microphone
- Open source: [github.com/alandaitch/live-fact-checker](https://github.com/alandaitch/live-fact-checker) (115 stars)
- Key differentiator: Full pipeline with color-coded inline highlights, hover tooltips, exportable HTML reports
- Limitation: Single LLM (Gemini) for both claim extraction and verification — no independent cross-checking layer

**Factiverse Live**
- Web app (not a browser extension); used during major political debates
- Professional/journalist-focused tool for newsrooms
- Five-step pipeline: media ingestion → statement identification → cross-referencing → feedback → documentation
- Deployed during 2024 US presidential debate; identified 757 claims
- Key differentiator: Professional-grade, used by Nordic verification groups (TjekDet)
- Limitation: Not a consumer product; requires file upload, not real-time streaming

**LiveFC (Research System)**
- Academic system from TU Delft / Factiverse; not open-sourced
- Whisper Live (large-v3) for streaming transcription + Mistral-7b for claim extraction + custom XLM-RoBERTa for check-worthiness and NLI
- 83.92 macro-F1 score against human evaluators
- During 2024 US debate, caught all 30 claims identified by PolitiFact plus additional ones
- Key differentiator: Custom classifiers outperform commercial LLMs (which suffered hallucination)
- Limitation: Research-only; code not publicly available

**Ganzo (Stanzo)**
- Web app using browser microphone; very early stage (2 commits, March 2026)
- Deepgram Nova-3 for transcription + Gemini 2.0 Flash for claim extraction + Perplexity Sonar for verification
- Uses Convex for reactive real-time UI updates
- Key differentiator: Speech pause detection triggers claim extraction
- Limitation: Barely functional; proof of concept

**CaptainFact**
- YouTube-focused; Chrome and Firefox extensions
- Community-driven (human fact-checking, not AI)
- Collaborative platform where users add fact-checks as overlays on videos
- Open source (MIT license)
- Key differentiator: "Wikipedia for video fact-checks" — community-powered
- Limitation: Not automated; requires human contributors

### Adjacent Tools (Text/Article-Level, Not Real-Time)

**Grok Disinformation Checker (Grok It)** — Chrome/Edge; uses xAI's Grok 4 + Live Search; generates Trust Score 0-100; open source.

**Omniscient AI** — Chrome + API; queries ChatGPT + Perplexity + Gemini simultaneously; "consensus factuality score"; voice-driven interface for field reporters.

**Aletheia** — Research extension (arXiv 2603.05519); RAG + GPT-4 with iterative query reformulation; F1 score 0.85; includes Discussion Hub for user dialogue.

**NewsGuard** — Source-level credibility ratings (not claim-level); human analysts rate domains; industry standard for source trust.

**Ground News Bias Checker** — Shows political bias distribution and how the same story is covered across the political spectrum.

### What FactShield Does Differently

| Feature | InTruth | Facticity AI | LiveFC | FactShield |
|---------|---------|-------------|--------|------------|
| Multi-source cross-verification | No (single LLM) | No (single LLM) | Yes (3 sources) | Yes (4+ sources with weighted voting) |
| Non-LLM verification layer | No | No | Yes (XLM-RoBERTa) | Yes (XLM-RoBERTa + ClaimReview DB) |
| Previously verified claims DB | No | No | Yes (280K) | Yes (Qdrant vector store) |
| Dynamic Island (iOS) | No | No | No | Yes (first-mover) |
| ReplayKit system audio capture | No | No | No | Yes (Mode B) |
| Source bias tracking | No | No | No | Yes (Media Bias/Fact Check integration) |
| Temporal evidence validation | No | No | Partial | Yes (prevents temporal leakage) |
| Dissent preservation | No | No | No | Yes (credible contradictions surfaced) |
| Open-source pipeline | No | Yes | No | Planned |

---

## Part 9: Top Research Papers Informing the Architecture

These are the most impactful academic papers that should directly inform FactShield's technical decisions.

### 1. LiveFC: A System for Live Fact-Checking of Audio Streams (2024)
- **Authors:** Venktesh V (TU Delft), Vinay Setty (Factiverse)
- **URL:** [arxiv.org/abs/2408.07448](https://arxiv.org/abs/2408.07448)
- **Why it matters:** The only end-to-end system for real-time fact-checking of continuous audio streams. Architecture pattern: Whisper Live → speaker diarization → Mistral-7b claim extraction → XLM-RoBERTa NLI → live dashboard. 83.92 macro-F1 against human evaluators. Custom classifiers beat commercial LLMs.

### 2. ClaimCheck: Real-Time Fact-Checking with Small Language Models (2025)
- **Authors:** Putta, Devasier, Li
- **URL:** [arxiv.org/abs/2510.01226](https://arxiv.org/abs/2510.01226)
- **Why it matters:** Proves that **Qwen3-4B** (a tiny 4B parameter model) achieves 76.4% fact-checking accuracy by mimicking human verification workflows. This is the latency-cost sweet spot for a live product. If you can use Qwen3-4B for the fast path and only escalate to qwen-max for complex claims, you dramatically reduce API costs and latency.

### 3. DEFAME: Dynamic Evidence-based FAct-checking with Multimodal Experts (ICML 2025)
- **Authors:** Braun, Rothermel, Rohrbach, Rohrbach
- **URL:** [arxiv.org/abs/2412.10510](https://arxiv.org/abs/2412.10510) | [GitHub](https://github.com/multimodal-ai-lab/DEFAME)
- **Why it matters:** Six-stage modular pipeline with **dynamic search depth** — the system decides when it has enough evidence to render a verdict vs. when to search deeper. This adaptive approach is critical for a real-time product: easy claims get fast verdicts, hard claims get deeper investigation. State-of-the-art on all established benchmarks.

### 4. FIRE: Fact-checking with Iterative Retrieval and Verification (NAACL 2025)
- **Authors:** Xie, Xing, Wang, Geng, Iqbal, Sahnan, Gurevych, Nakov
- **URL:** [arxiv.org/abs/2411.00784](https://arxiv.org/abs/2411.00784) | [GitHub](https://github.com/mbzuai-nlp/fire)
- **Why it matters:** Agent-based framework that iteratively alternates between evidence retrieval and verification, with **confidence-based early exit**. Reduces LLM API costs by 7.6x and retrieval costs by 16.5x while maintaining accuracy. The confidence-based stopping criterion is exactly what a production system needs to balance speed vs. thoroughness.

### 5. SAFE: Search-Augmented Factuality Evaluator (Google DeepMind, 2024)
- **Authors:** Wei, Yang, Song, Lu, et al. (Google DeepMind)
- **URL:** [arxiv.org/abs/2403.18802](https://arxiv.org/abs/2403.18802) | [GitHub](https://github.com/google-deepmind/long-form-factuality)
- **Why it matters:** The gold standard for automated factuality scoring. Decomposes text into atomic claims, generates search queries for each, uses chain-of-thought reasoning over search results. Automated evaluator agrees with humans ~72% of the time; on disagreements, automated evaluator wins 76% of the time. 20x cheaper than human evaluation.

### 6. Resolving Conflicting Evidence in Automated Fact-Checking (IJCAI 2025)
- **Authors:** Ge, Wu, Chin, Lee, Cao
- **URL:** [arxiv.org/abs/2505.17762](https://arxiv.org/abs/2505.17762)
- **Why it matters:** First comprehensive study of how RAG-based fact-checking systems handle **conflicting evidence from sources with varying credibility**. Proposes integrating media credibility scores into both retrieval ranking and generation prompting. Directly applicable to FactShield's source diversity enforcement and dissent preservation.

### 7. LiveFact: Dynamic Time-Aware Benchmark for LLM-Driven Fake News Detection (2026)
- **URL:** [arxiv.org/abs/2604.04815](https://arxiv.org/abs/2604.04815)
- **Why it matters:** Introduces the concept of **"epistemic humility"** — the model's ability to say "not enough evidence yet" for emerging claims. This is critical for a real-time product where premature verdicts damage credibility. The temporal uncertainty modeling directly informs how FactShield should handle claims where evidence is still developing.

### 8. CLIMINATOR: Automated Fact-Checking of Climate Claims with LLMs (Nature, 2025)
- **Authors:** Leippold, Vaghefi, Stammbach, et al.
- **URL:** [nature.com/articles/s44168-025-00215-8](https://www.nature.com/articles/s44168-025-00215-8)
- **Why it matters:** The **Mediator-Advocate multi-agent architecture** is a powerful pattern for cross-verification. Multiple RAG agents evaluate claims against different corpora, a Mediator aggregates findings, and an adversarial agent stress-tests against counterarguments. 97% accuracy on Climate Feedback dataset. This adversarial testing approach could be adapted for FactShield's cross-checking layer.

### 9. FActScore: Fine-grained Atomic Evaluation of Factual Precision (EMNLP 2023)
- **Authors:** Min, Krishna, Lyu, et al.
- **URL:** [arxiv.org/abs/2305.14251](https://arxiv.org/abs/2305.14251)
- **Why it matters:** Foundational metric for factuality evaluation. Decomposes text into "atomic facts" (minimal verifiable units) and measures the fraction supported by a knowledge source. Simple, interpretable metric that stakeholders can understand. The atomic fact decomposition is directly reusable in FactShield's claim extraction module.

### 10. Show Me the Work: Fact-Checkers' Requirements for Explainable AFC (2025)
- **Authors:** Warren, Shklovski, Augenstein
- **URL:** [arxiv.org/abs/2502.09083](https://arxiv.org/abs/2502.09083)
- **Why it matters:** Qualitative study interviewing professional fact-checkers about what they need from automated systems. Four requirements: (1) trace reasoning paths, (2) cite evidence with sources, (3) acknowledge missing information and uncertainty, (4) enable replicability. These should be the UX design principles for FactShield's output format.

### Key Insight from the Research

**ClaimCheck's finding is the most actionable:** A 4B parameter model (Qwen3-4B) can do real-time fact-checking at 76.4% accuracy. This means FactShield should implement a **two-tier architecture**:

- **Fast path:** Qwen3-4B (or qwen-plus) handles straightforward claims with high confidence. These get verdicts in 3-5 seconds.
- **Deep path:** When the fast path has low confidence (< 70%) or the claim is complex, escalate to qwen-max with full multi-source RAG pipeline. These take 8-12 seconds but produce more thorough verdicts.

This tiered approach, combined with FIRE's confidence-based early exit, gives FactShield the best balance of speed and accuracy.

---

## Conclusion

FactShield's competitive advantage is its **triple-verification pipeline** that mirrors what the best journalism organizations do manually — but at machine speed. By combining live retrieval-augmented generation (never relying on LLM training data), multi-source cross-checking, weighted majority voting, and full transparency with ranked sources and reasoning chains, FactShield delivers verdicts that are both fast and trustworthy.

The browser extension provides the broadest coverage across platforms, while the iOS app offers a uniquely frictionless experience through the Dynamic Island — making fact-checking as natural as glancing at your phone's notch.

No existing fact-checking app uses the Dynamic Island. This is a first-mover opportunity.
