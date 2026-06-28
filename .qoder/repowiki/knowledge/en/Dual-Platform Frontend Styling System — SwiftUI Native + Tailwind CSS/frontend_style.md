## Overview

FactShield employs two distinct frontend styling systems tailored to each platform:

1. **iOS App**: Pure SwiftUI with native design tokens, system colors, and `.ultraThinMaterial` backgrounds
2. **Chrome Extension**: Tailwind CSS (CDN) with custom dark theme, semantic color tokens, and hand-crafted animations

Both platforms share a consistent visual language for verdict states (True/False/Misleading) using matching color semantics.

---

## iOS App — SwiftUI Native Design System

### Approach
The iOS app uses **SwiftUI's built-in styling primitives** with no third-party UI framework. It relies on:
- System SF Symbols for iconography
- Semantic `Color` values (`.green`, `.red`, `.orange`, `.yellow`, `.gray`)
- Material effects (`.ultraThinMaterial`) for card backgrounds
- Standard typography scale (`.caption`, `.subheadline`, `.body`, `.headline`, `.title2`, `.title3`)

### Key Files
- `FactShield/FactShield/Features/FactCheck/FactCheckSessionView.swift` — Primary view with verdict cards, claim cards, status indicators
- `FactShield/FactShield/Features/Home/HomeView.swift` — Hero card, active session banner, step-by-step guide
- `FactShield/FactShield/Features/Settings/SettingsView.swift` — Form-based settings with secure inputs
- `FactShield/FactShield/App/FactShieldApp.swift` — Tab navigation, history rows

### Color Semantics (Verdict Mapping)
All verdict-related views use consistent color functions:

| Verdict Type | Color |
|---|---|
| `.true` | `.green` |
| `.substantiallyTrue` | `.yellow` |
| `.misleading` | `.orange` |
| `.false` | `.red` |
| `.unverifiable` | `.gray` |

These are implemented as private helper functions (`verdictColor(_:)`) duplicated across `FactCheckSessionView`, `FactShieldApp`, and `ClaimListRow`.

### Layout Conventions
- **Card radius**: `RoundedRectangle(cornerRadius: 12)` is the standard; hero/how-it-worth sections use `cornerRadius: 16`
- **Padding**: `.padding()` (default 16pt) on card containers; `.padding(.horizontal, 8)` / `.padding(.vertical, 3)` on badges
- **Backgrounds**: `.ultraThinMaterial` is used universally for cards, creating a frosted-glass effect that adapts to light/dark mode
- **Borders**: Verdict cards use colored stroke overlays at 0.2 opacity: `.stroke(verdictColor(...).opacity(0.2), lineWidth: 1)`
- **Badges**: Capsule-shaped with 15% opacity background: `.background(color.opacity(0.15))`

### Typography Scale
- `.caption2` — Timestamps, secondary metadata
- `.caption` — Labels, badge text
- `.subheadline` — Claim text, reasoning summaries
- `.body` — Primary claim display
- `.headline` — Section headers, confidence percentages
- `.title3` — Verdict type labels, claim counts
- `.title2` — Status icons

### Animations
- `.symbolEffect(.pulse, isActive:)` — Pulsing waveform icon during active sessions
- `.transition(.move(edge: .top).combined(with: .opacity))` — Claim card entrance
- `.animation(.easeInOut(duration: 0.3), value:)` — Smooth state transitions on claim/verdict changes

---

## Chrome Extension — Tailwind CSS Dark Theme

### Approach
The Chrome extension side panel uses **Tailwind CSS via CDN** with a fully custom dark theme configuration. No build tooling or PostCSS pipeline is involved.

### Key Files
- `FactShield-ChromeExtension/src/sidepanel/index.html` — Tailwind config injection point
- `FactShield-ChromeExtension/src/sidepanel/styles.css` — Custom animations, scrollbar styling, hover effects
- `FactShield-ChromeExtension/src/sidepanel/app.js` — Template rendering with verdict config constants

### Tailwind Configuration (`index.html`)
```javascript
tailwind.config = {
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        fs: {
          bg: '#0F172A',       // Slate 900
          card: '#1E293B',     // Slate 800
          text: '#F8FAFC',     // Slate 50
          muted: '#94A3B8',    // Slate 400
          accent: '#3B82F6',   // Blue 500
          border: '#334155',   // Slate 700
          true: '#10B981',     // Emerald 500
          'sub-true': '#14B8A6', // Teal 500
          misleading: '#F59E0B', // Amber 500
          false: '#EF4444',    // Red 500
          unverifiable: '#6B7280', // Gray 500
        }
      },
      fontFamily: {
        sans: ['system-ui', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'Roboto', 'sans-serif']
      },
      maxWidth: { panel: '400px' }
    }
  }
}
```

### VERDICT_CONFIG (app.js)
JavaScript-side verdict styling mirrors the Tailwind tokens:
```javascript
const VERDICT_CONFIG = {
  TRUE: { label: 'Verified True', color: '#10B981', bg: 'bg-emerald-500/20', text: 'text-emerald-400', border: 'border-emerald-500/30' },
  SUBSTANTIALLY_TRUE: { label: 'Substantially True', color: '#14B8A6', bg: 'bg-teal-500/20', text: 'text-teal-400', border: 'border-teal-500/30' },
  MISLEADING: { label: 'Misleading', color: '#F59E0B', bg: 'bg-amber-500/20', text: 'text-amber-400', border: 'border-amber-500/30' },
  FALSE: { label: 'False', color: '#EF4444', bg: 'bg-red-500/20', text: 'text-red-400', border: 'border-red-500/30' },
  UNVERIFIABLE: { label: 'Unverifiable', color: '#6B7280', bg: 'bg-gray-500/20', text: 'text-gray-400', border: 'border-gray-500/30' },
};
```

### Custom Animations (styles.css)
The extension defines 10+ keyframe animations:
- `pulse-verify` — Pulsing scale/opacity for verifying state
- `slide-in` — Verdict card entrance (translateY + fade)
- `fill-meter` — Confidence meter width animation
- `fade-in` — Generic fade entrance
- `blink-dot` — Status dot blinking
- `gradient-move` — Animated gradient on progress bar
- `spin-slow` — Spinner rotation (1.5s linear)
- `toast-in` / `toast-out` — Toast notification slide
- `shimmer` — Loading skeleton shimmer effect

### Component Patterns
- **Cards**: `bg-fs-card border border-fs-border rounded-xl p-3` with hover lift effect (`transform: translateY(-1px)`)
- **Badges**: Inline-flex with opacity backgrounds (`bg-emerald-500/20`) and colored borders
- **Progress bars**: Animated gradient (`linear-gradient(90deg, #3B82F6, #8B5CF6, #3B82F6)`)
- **Scrollbars**: Custom WebKit styling with slate-colored track/thumb
- **Buttons**: `.btn-press` class with `scale(0.97)` on active state
- **Expandable sections**: Max-height transition with cubic-bezier easing

---

## Cross-Platform Consistency Rules

1. **Verdict color mapping must match** between iOS (SwiftUI Color) and Chrome (Tailwind hex):
   - True → Green/Emerald (#10B981)
   - Substantially True → Yellow/Teal (#14B8A6)
   - Misleading → Orange/Amber (#F59E0B)
   - False → Red (#EF4444)
   - Unverifiable → Gray (#6B7280)

2. **No hardcoded colors in logic** — Both platforms centralize verdict colors in helper functions/constants (`verdictColor(_:)` in Swift, `VERDICT_CONFIG` in JS).

3. **Dark-first design** — iOS uses `.ultraThinMaterial` which adapts; Chrome explicitly sets `<html class="dark">` with slate-based palette.

4. **Animation duration consistency** — Both platforms target ~300ms for card entrances and state transitions.

---

## Developer Guidelines

### Adding New Verdict Types
1. Update `Verdict.VerdictType` enum in `FactShield/FactShield/Models/Enums.swift`
2. Add case to all `verdictColor(_:)` functions (found in `FactCheckSessionView.swift`, `FactShieldApp.swift`)
3. Add entry to `VERDICT_CONFIG` in `app.js`
4. Add corresponding Tailwind color token in `index.html` if new hex value needed

### Styling New Components
- **iOS**: Use `.ultraThinMaterial` background, `RoundedRectangle(cornerRadius: 12)`, and semantic `.foregroundStyle()` modifiers. Avoid hardcoded `Color.red` — use verdict/status color helpers.
- **Chrome**: Use `fs-*` color tokens from Tailwind config. Apply `verdict-card` class for hover effects. Use existing animation classes (`animate-slide-in`, `animate-fade-in`) rather than writing new keyframes.

### Responsive Strategy
- **iOS**: Relies on SwiftUI's adaptive layout; no explicit breakpoints
- **Chrome**: Fixed `max-w-panel` (400px) centered layout; no mobile breakpoint handling (side panel has fixed dimensions)
