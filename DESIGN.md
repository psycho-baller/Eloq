# Eloq Design System

## Product Posture
- Eloq is a calm lexical companion.
- The product is about vocabulary expansion, not chat, coaching theater, or productivity dashboards.
- The UI should feel editorial, precise, and slightly formal without becoming academic or cold.

## Core Principles
- Action first: adding a word is the primary action on every fresh launch.
- Graph visible, not overwhelming: users should feel the overused/underused relationship system immediately, but never face a dense graph visualization in v1.
- AI as annotation: AI appears as rationale, confidence, and link suggestions, not as a chat transcript.
- Local trust: local save health and export health must always be legible.
- Low-friction review: accepting or dismissing a suggestion should take one click and remain reversible.

## Visual Direction
- Dark-first editorial lexicon with Linear-grade polish.
- One dominant canvas tone, one elevated panel tone, one restrained accent.
- No bright AI gradients, neon glows, or playful motion.
- Surfaces should read as deliberate workspaces, not consumer productivity cards.

## Typography
- Display and lexical emphasis: `New York`.
- Body, controls, tables, and utility text: `SF Pro`.
- Counts, confidence, and timestamps: tabular numerals where available.

### Type Scale
- Hero title: `34`
- Section title: `24`
- Large metric: `42`
- Body: `14` to `15`
- Utility and health text: `11` to `13`

## Spacing And Layout
- Base spacing scale: `4 / 8 / 12 / 16 / 24 / 32`
- App padding: `24`
- Panel padding: `20` to `24`
- Dense row spacing is allowed inside suggestion lists, but panels must still breathe.
- The right rail can be information-dense; the primary column must stay visually calm.

## Color System
- Canvas: `#12161A`.
- Elevated panel: `#1B2127`.
- Raised panel or quiet control surface: `#222A32`.
- Primary text: `#F2EEE7`.
- Secondary text: `#A6B0B6`.
- Accent: `Eloq Verdigris` `#79AFA3`.
- Accent pressed/deeper state: `#5D8F84`.
- Accent wash: `rgba(121, 175, 163, 0.18)`.
- Partial health: muted amber `#C69662`.
- Error health: restrained red `#B46E69`.
- The same Eloq accent must be used in both the macOS app and the Obsidian plugin for primary actions, accepted links, and healthy state.

## Surface Model
- One page canvas.
- One reusable elevated panel component.
- One chip style family for roles and statuses.
- Suggestion rows are annotated list items, never chat bubbles.

## Information Architecture

### Home
- Primary: quick add and capture.
- Secondary: pending inbox count.
- Tertiary: import summary and health.

### Inbox
- Pending suggestions first.
- Reviewed suggestions second.
- Each row shows the lexical move, rationale, confidence, use case, and caution.

### Library
- Search plus `All`, `Overused`, and `Underused`.
- Word detail is contextual rather than modal-first.
- Connections must make the opposite side legible immediately.

## Component Rules

### Quick Add
- Large term input.
- Segmented control for `Overused` vs `Underused`.
- Primary save button.
- Secondary capture button.
- Capture state should explain the Accessibility fallback clearly.

### Suggestion Row
- Headline uses the lexical move: `overused -> underused`.
- Confidence stays compact and numeric.
- Rationale is one short paragraph.
- `Use when` and `Caution` are supporting annotation lines.
- Accept and dismiss remain on the row; restore appears only after review.

### Health Pill
- Always visible in the header.
- Must distinguish:
  - local-first idle
  - healthy export
  - partial degradation
  - explicit error
- Full diagnostics are out of scope for v1, so the pill text must carry enough meaning on its own.

## Interaction States

### Home
- Empty: explain the model with one concrete example.
- Success: show saved confirmation and route attention to the inbox.
- Partial: local save succeeded but export or AI degraded.
- Error: explicit save or export failure copy.

### Inbox
- Loading: concise activity state, not a spinner wall.
- Empty: “No suggestions to review yet” plus the next obvious action.
- Partial: some suggestion generation failed but existing work remains usable.
- Error: AI unavailable with retry path implied by future actions.

### Import
- Empty: no Audora vocabulary found.
- Success: words, links, and skips summarized in one line.
- Partial: conflicted or skipped items reported without blocking good imports.
- Error: parsing or disk failure stated plainly.

## Motion
- Short, precise transitions only.
- Prefer fades, opacity shifts, and slight scale changes.
- No bounce, spring theatrics, or chat-like typing animation.
- Reduced-motion users should lose animation, not meaning.

## Accessibility
- Full keyboard navigation across navigation chips, save actions, and suggestion actions.
- Minimum 44pt hit targets for actionable controls.
- VoiceOver labels should expose term, status, and action intent.
- Dark mode contrast must be checked directly; do not assume acceptable contrast from hue alone.

## Copy Style
- Concise and factual.
- No hype about AI.
- Avoid motivational language.
- Prefer “sharper”, “more precise”, “accepted link”, and “saved locally” over generic assistant phrasing.

## V1 Non-Goals
- Corpus atlas or graph visualization.
- Daily streaks or gamification.
- Full diagnostics console.
- Chat-first AI surface.
- iOS-specific layout work.

## Implementation Notes
- The Mac app is the source of truth for writing vocabulary.
- Obsidian and the browser extension are read-only Eloq consumers in v1.
- Local save must work without CloudKit or OpenAI.
- Any future UI additions should extend this document instead of introducing a second style vocabulary.
