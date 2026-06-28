## Overview

FactShield employs a dual-platform frontend styling strategy:

1. **iOS App**: Native SwiftUI with system-level design tokens and adaptive theming
2. **Chrome Extension**: Tailwind CSS (CDN) with custom dark theme design tokens and hand-crafted animations

Both platforms share a consistent visual language centered around a dark color palette, blue accent colors, and status-coded verdict indicators.

---

## iOS Styling Architecture (SwiftUI)

### Design Approach
The iOS app leverages SwiftUI's declarative styling system with no external UI framework dependencies. Styling is achieved through:

- **System-provided materials**: `.ultraThinMaterial` for card backgrounds providing glassmorphism effects
- **Semantic color roles**: `.primary`, `.secondary`, `.tertiary` for text hierarchy; `.blue`, `.green`, `.red`, `.orange`, `.yellow`, `.gray` for status indicators
- **SF Symbols**: System iconography via `Image(systemName:)` for consistent iconography
- **Built-in button styles**: `.borderedProminent`, `.bordered`, `.plain` for interactive elements
- **Rounded rectangles**: Uniform `cornerRadius: 12` or `16` for card containers

### Color Semantics
Verdict types map to specific colors consistently across views:
- **True** → `.green`
- **Substantially True** → `.yellow`
- **Misleading** → `.orange`
- **False** → `.red`
- **Unverifiable** → `.gray`

Check worthiness badges use:
- **High** → `.red`
- **Medium** → `.orange`
- **Low** → `.gray`

### Asset Configuration
Design tokens are stored in Xcode asset catalogs:
- `AccentColor.colorset`: Primary brand accent (currently unconfigured with explicit values)
- `WidgetBackground.colorset`: Widget-specific background (currently unconfigured)

These empty colorsets indicate reliance on system defaults rather than explicit brand colors.

### Layout Conventions
- Cards use `.padding()` (default 16pt) with `.ultraThinMaterial` backgrounds
- Section headers use `.font(.headline)` or `.font(.caption.bold())` with `.foregroundStyle(.secondary)`
- Body text uses `.font(.body)` or `.font(.subheadline)`
- Metadata uses `.font(.caption)` or `.font(.caption2)` with `.foregroundStyle(.secondary)` or `.tertiary`

---

## Chrome Extension Styling Architecture

### Technology Stack
- **Tailwind CSS v3** loaded via CDN (`https://cdn.tailwindcss.com`)
- **Custom design tokens** defined inline in each HTML file's `<script>` block
- **Supplementary CSS** in `styles.css` for animations and custom scrollbar styling

### Design Token System
A custom `fs` (FactShield) color namespace is defined in Tailwind config:

```javascript
colors: {
  fs: {
    bg: '#0F172A',        // Slate 900 - page background
    card: '#1E293B',      // Slate 800 - card surfaces
    text: '#F8FAFC',      // Slate 50 - primary text
    muted: '#94A3B8',     // Slate 400 - secondary text
    accent: '#3B82F6',    // Blue 500 - primary action color
    border: '#334155',    // Slate 700 - borders/dividers
    true: '#10B981',      // Emerald 500
    'sub-true': '#14B8A6',// Teal 500
    misleading: '#F59E0B',// Amber 500
    false: '#EF4444',     // Red 500
    unverifiable: '#6B7280'// Gray 500
  }
}
```

This token system is duplicated across `sidepanel/index.html` and `options/index.html`, creating a maintenance concern.

### Verdict Color Mapping (JavaScript)
The `VERDICT_CONFIG` object in `app.js` defines verdict styling with both hex colors and Tailwind utility classes:

```javascript
TRUE: { color: '#10B981', bg: 'bg-emerald-500/20', text: 'text-emerald-400', border: 'border-emerald-500/30' }
SUBSTANTIALLY_TRUE: { color: '#14B8A6', bg: 'bg-teal-500/20', text: 'text-teal-400', border: 'border-teal-500/30' }
MISLEADING: { color: '#F59E0B', bg: 'bg-amber-500/20', text: 'text-amber-400', border: 'border-amber-500/30' }
FALSE: { color: '#EF4444', bg: 'bg-red-500/20', text: 'text-red-400', border: 'border-red-500/30' }
UNVERIFIABLE: { color: '#6B7280', bg: 'bg-gray-500/20', text: 'text-gray-400', border: 'border-gray-500/30' }
```

Note the slight inconsistency: Tailwind config uses `fs.true` but JavaScript uses direct hex values and standard Tailwind color names.

### Animation System
Custom keyframe animations are defined in `styles.css`:

| Animation | Purpose | Duration | Easing |
|-----------|---------|----------|--------|
| `pulse-verify` | Active state indicator | 1.5s infinite | ease-in-out |
| `slide-in` | Verdict card entrance | 0.35s | cubic-bezier(0.16, 1, 0.3, 1) |
| `fill-meter` | Confidence meter fill | 0.8s | cubic-bezier(0.33, 1, 0.68, 1) |
| `fade-in` | Generic fade entrance | 0.3s | ease-out |
| `blink-dot` | Status dot pulsing | 1.2s infinite | ease-in-out |
| `gradient-move` | Progress bar shimmer | 2s infinite | linear |
| `spin-slow` | Loading spinner | 1.5s infinite | linear |
| `toast-in/toast-out` | Notification transitions | 0.3s | ease-out/ease-in |
| `shimmer` | Skeleton loading effect | 1.5s infinite | - |

### Component Patterns
- **Cards**: `bg-fs-card border border-fs-border rounded-xl p-3` with hover effects (`transform: translateY(-1px)`, enhanced shadow)
- **Buttons**: `.btn-press` class adds `scale(0.97)` on active state
- **Expandable sections**: CSS transition on `max-height` with opacity fade
- **Custom scrollbar**: Webkit-only styling with 5px width, slate-colored track/thumb
- **Toast notifications**: Fixed positioning with enter/exit animations

### Typography
System font stack: `system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, sans-serif`

Text sizing follows Tailwind defaults:
- Headers: `text-sm font-bold` (14px)
- Body: `text-xs` (12px)
- Metadata: `text-[10px]` or `text-[11px]` (custom sizes)

---

## Cross-Platform Consistency

### Shared Visual Language
Both platforms maintain consistency through:
1. **Dark theme as default**: iOS uses system materials; Chrome uses `#0F172A` background
2. **Same verdict color semantics**: Green=true, Red=false, Orange=misleading, Gray=unverifiable
3. **Card-based layout**: Rounded containers with subtle borders/backgrounds
4. **Status indicators**: Animated dots/pulses for active states
5. **Hierarchical text**: Primary/secondary/muted text levels

### Key Differences
| Aspect | iOS | Chrome Extension |
|--------|-----|------------------|
| Framework | SwiftUI native | Tailwind CSS CDN |
| Theming | System-adaptive | Fixed dark mode |
| Animations | SF Symbol effects, SwiftUI transitions | Custom CSS keyframes |
| Icons | SF Symbols | Inline SVG / Emoji |
| Design tokens | Implicit (system colors) | Explicit (custom `fs` namespace) |

---

## Developer Guidelines

### For iOS (SwiftUI)
1. Use `.ultraThinMaterial` for card backgrounds to maintain visual consistency
2. Apply `cornerRadius: 12` for standard cards, `16` for hero/large sections
3. Use semantic foreground styles: `.primary`, `.secondary`, `.tertiary`
4. Map verdict types to colors via the established switch pattern in `VerdictCard`
5. Prefer SF Symbols for icons; use `.symbolEffect(.pulse)` for active states
6. Keep padding consistent: `.padding()` for content, `.padding(24)` for hero sections

### For Chrome Extension
1. Always use `fs-*` prefixed Tailwind classes for FactShield-specific colors
2. Apply `.verdict-card` class to all claim/verdict containers for consistent hover effects
3. Use `.animate-slide-in` for new verdict card entrances
4. Use `.confidence-fill` with `--fill-width` CSS variable for confidence meters
5. Apply `.btn-press` to interactive buttons for tactile feedback
6. Use `.custom-scrollbar` on scrollable containers
7. Maintain the verdict color mapping in `VERDICT_CONFIG` when adding new verdict types
8. Keep animation durations consistent with existing patterns (0.3s for UI transitions, 1.5s for ambient animations)

### Maintenance Concerns
1. **Token duplication**: The Tailwind config is duplicated between `sidepanel/index.html` and `options/index.html`. Consider extracting to a shared JS module.
2. **iOS color assets**: `AccentColor.colorset` and `WidgetBackground.colorset` are empty. Define explicit brand colors if custom theming is needed beyond system defaults.
3. **Color consistency**: Chrome extension uses both `fs.true` (Tailwind config) and direct hex values (JavaScript). Standardize on one approach.