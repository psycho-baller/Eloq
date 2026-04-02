# Eloq

Eloq is a local-first macOS app for building a personal vocabulary graph. It lets you collect words in two buckets:

- `overused`: words and phrases you lean on too often
- `underused`: sharper words you want to reach for more often

From there, Eloq helps you connect the two sides, review AI-generated suggestions, and export a snapshot that other Audora tools can consume.

## What It Does

- Stores words, roles, and accepted links locally with SwiftData
- Captures the current text selection with the global shortcut `Control + Option + Command + L`
- Falls back to the clipboard when Accessibility capture is unavailable
- Imports legacy Audora writing-awareness vocabulary from `seed.json` and `state.json`
- Exports the current vocabulary graph to a JSON snapshot on disk
- Serves the latest snapshot over a local HTTP bridge for read-only consumers
- Uses the OpenAI Responses API for optional connection suggestions

Eloq is the source of truth for writing vocabulary in this repo. The Obsidian plugin and browser extension consume Eloq output; they do not own the data model.

## Audora Consumers

Two downstream Audora surfaces read Eloq's exported snapshot and apply it in context:

### Obsidian Plugin

The Obsidian plugin is a note-editing companion for long-form writing. It loads the Eloq snapshot from disk, watches for changes, and analyzes the active note as you type in Source mode and Live Preview.

- flags overused terms with actionable replacements
- optionally underlines rewarded target words Eloq wants to reinforce
- lets you jump to the next or previous issue from commands
- lets you apply nearby suggestions directly in the editor
- keeps vocabulary management read-only, so new words still get added in the macOS app

In practice, it feels like a quiet editorial layer inside Obsidian: local, document-aware, and focused on helping you revise prose against the vocabulary graph you already curated in Eloq.

### Browser Extension

The browser extension brings the same vocabulary awareness into live web text fields and contenteditable editors. It treats Eloq as a read-only upstream source and refreshes from the local snapshot bridge when the app is running, with a native-host fallback when needed.

- highlights accepted Eloq links inline while you write on the web
- shows lightweight popovers with rationale, cautions, and quick replacements
- exposes a popup and options page for snapshot status, focus words, and muted sites
- supports per-site muting so hints stay out of places where they are not useful
- records lightweight reinforcement events without turning the browser into the editing authority

It is the faster, more ambient consumer: less about deliberate revision, more about keeping your Eloq vocabulary graph present while you write across the web.

## Project Layout

```text
apps/Eloq/
├── Eloq/             # SwiftUI app source
├── EloqTests/        # Swift tests
├── EloqUITests/      # UI tests
├── Eloq.xcodeproj    # Xcode project
└── DESIGN.md         # Product and design notes
```

## Requirements

- Xcode with Swift 5 support
- The current project deployment target is `macOS 26.2`
- macOS Accessibility permission if you want true global selection capture
- An OpenAI API key if you want AI suggestions

## Run The App

Open the project in Xcode:

```bash
open apps/Eloq/Eloq.xcodeproj
```

Or build and run from the command line:

```bash
xcodebuild -project apps/Eloq/Eloq.xcodeproj -scheme Eloq -destination 'platform=macOS' build
```

## Run Tests

```bash
xcodebuild test -project apps/Eloq/Eloq.xcodeproj -scheme Eloq -destination 'platform=macOS'
```

## Storage And Integration

Eloq uses these local paths:

- Eloq storage root: `~/Library/Application Support/Eloq`
- Exported snapshot: `~/Library/Application Support/Eloq/snapshot.json`
- Legacy Audora import folder: `~/Library/Application Support/Audora/WritingAwareness`

The app also exposes the current snapshot over localhost:

- Snapshot bridge: [http://127.0.0.1:43827/snapshot](http://127.0.0.1:43827/snapshot)

## OpenAI Setup

OpenAI is optional. Manual vocabulary management, import, and export still work without it.

If you add a key in Eloq Settings:

- the key is stored in the macOS Keychain
- Eloq uses the Responses API to propose opposite-side vocabulary links
- generated suggestions appear in the Inbox for review before they become accepted links

## Typical Workflow

1. Add a word or phrase as `overused` or `underused`.
2. Capture new terms while writing with the global shortcut.
3. Review suggested links in the Inbox.
4. Accept, dismiss, or create manual links in the Library.
5. Export the snapshot for downstream Audora consumers.

## Notes

- Global capture asks for Accessibility access the first time you use it.
- Snapshot export happens automatically after changes and can also be triggered manually.
- `DESIGN.md` documents the intended product posture and UI direction.
