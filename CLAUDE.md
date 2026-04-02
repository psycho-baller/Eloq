# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Open in Xcode
open Eloq.xcodeproj

# Build from command line
xcodebuild -project Eloq.xcodeproj -scheme Eloq -destination 'platform=macOS' build

# Run all tests
xcodebuild test -project Eloq.xcodeproj -scheme Eloq -destination 'platform=macOS'

# Run a single test class
xcodebuild test -project Eloq.xcodeproj -scheme Eloq -destination 'platform=macOS' -only-testing EloqTests/EloqTests
```

Requirements: Xcode, macOS 26.2+ deployment target.

## Architecture

Eloq is a local-first macOS SwiftUI app for vocabulary graph management. Data is persisted with SwiftData; there is no cloud sync.

### Data Model (`EloqModels.swift`)

Three SwiftData entities form the core graph:
- **`Word`** — a vocabulary item (display term, normalized form, notes, examples, contexts, provenance)
- **`WordRole`** — tags a word as `overused` or `underused`; one word can hold both roles
- **`WordConnection`** — a directed link from an overused word to an underused alternative, with rationale, confidence, and status (`suggested` / `accepted` / `dismissed`)

JSON snapshot models (`SnapshotWord`, `SnapshotConnection`) mirror these for disk export and downstream consumption. Legacy Audora import structures (`AudoraLegacySeed`, `AudoraLegacyState`) are also defined here.

### Central State (`EloqWorkspace.swift`)

`EloqWorkspace` is a `@MainActor ObservableObject` that owns all runtime state. It is the single source of truth wired into the SwiftUI environment:
- CRUD for words, roles, connections
- AI suggestion generation (delegates to `OpenAISuggestionService`)
- Snapshot export / import lifecycle
- Health status aggregation (local, export, AI)
- Global selection capture orchestration

The SwiftData `ModelContext` is injected into `EloqWorkspace` at app launch from the `ModelContainer` configured in `EloqApp.swift`.

### UI (`ContentView.swift`, `EloqSettingsView.swift`)

Four-tab navigation inside `ContentView`:
- **Home** — quick-add panel, metrics, recent words, import summary, health status
- **Inbox** — pending and reviewed AI-generated suggestions
- **Library** — searchable, filterable vocabulary list; accepts/dismisses connections
- **Atlas** — graph visualization (partially implemented)

`EloqSettingsView` has three tabs: AI (API key), Capture (Accessibility), Storage (paths, health, manual export/import).

### Services (`EloqAI.swift`, `EloqSystem.swift`)

- **`OpenAISuggestionService`** — calls OpenAI Responses API; builds structured prompts; parses JSON suggestions; result is a list of `ConnectionSuggestion` objects surfaced to the Inbox
- **`EloqSelectionCaptureManager`** — tries macOS Accessibility API first, falls back to clipboard; invoked by the global hotkey
- **`EloqGlobalHotKeyManager`** — registers `Control+Option+Command+L` system-wide
- **`EloqKeychain`** — reads/writes the OpenAI API key in the macOS Keychain
- **`EloqLocalBridge`** — HTTP server on `127.0.0.1:43827` serving `snapshot.json` read-only for Obsidian plugin and browser extension consumers

### Theming (`EloqTheme.swift`)

Dark-first design. Accent color is verdigris (`#79AFA3`). `EloqTheme` exports semantic color tokens and spacing constants. `EloqChip` is the reusable badge component. `EloqPanelGroupBoxStyle` is the standard panel container style.

## Storage Paths

| Path | Purpose |
|------|---------|
| `~/Library/Application Support/Eloq/` | App storage root |
| `~/Library/Application Support/Eloq/snapshot.json` | Exported vocabulary snapshot (auto-updated on change) |
| `~/Library/Application Support/Audora/WritingAwareness/` | Legacy Audora import source |
| `http://127.0.0.1:43827/snapshot` | Local HTTP bridge for downstream consumers |

## Key Design Constraints

- **Eloq is the data owner.** Downstream consumers (Obsidian plugin, browser extension) read the snapshot; they never write back.
- **Sandbox entitlements** in `Eloq.entitlements` restrict file access and network. Changes to capabilities must be reflected there.
- **OpenAI is optional.** All local features (add, capture, connect, export) work without an API key.
- **Default actor isolation is `@MainActor`** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in build settings). Mark background work with `nonisolated` or `Task.detached` explicitly.
- Tests use Swift Testing macros (`@Suite`, `@Test`) — not XCTest-style class methods.
