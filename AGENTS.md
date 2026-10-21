# scro — agent notes

Tiny macOS menu bar app (Swift 6, SwiftUI `MenuBarExtra`) that collects
screenshots taken with macOS built-in tools and offers prev/next browsing,
click-to-copy, and drag-out. Ships with a CLI (`scro-cli`, symlinked as `scro`)
that operates on the same captures folder — the folder is the source of truth,
no IPC.

## Layout

- `Sources/SCROCore` — shared: `Captures` (store dir, list, clear) + `Clipboard`
- `Sources/SCRO` — the menu bar app (target `SCRO`)
- `Sources/scro-cli` — the CLI (target `scro-cli`, `main.swift`)

## Build / run / test

- Build debug: `swift build`
- Build app bundle (app + CLI inside): `./scripts/bundle.sh` → `scro.app`,
  run with `open scro.app`
- Install CLI symlink: `./scripts/install-cli.sh` → `~/.local/bin/scro`
- Install/upgrade app: `./scripts/install-app.sh` (builds, replaces
  `/Applications/scro.app`, restarts it, re-points the CLI symlink)
- App icon: `./scripts/make-icon.sh` regenerates `AppIcon.icns` from
  `scripts/IconGen.swift` (Core Graphics — keep icon changes code-based, no
  binary design tools). `bundle.sh` copies it into `Contents/Resources/`.
- Release: `./scripts/release.sh [version]` builds, zips (`dist/`, gitignored),
  and publishes a GitHub release `v<version>` with a `.sha256` (needs `gh auth`).
- CI: `.github/workflows/ci.yml` runs debug + release builds on push to `main`
  and PRs (no publishing). Keep it green; releases stay manual.
- No test suite; manual test: `open scro.app`, take a screenshot with ⇧⌘4,
  confirm `scro list` shows it in `~/Library/Application Support/scro/captures/`.
- Binary names stay distinct on the case-insensitive FS: app binary `SCRO`,
  CLI binary `scro-cli` (do not rename either to `scro`).

## Environment constraint (important)

This machine has **Command Line Tools only, no full Xcode**. The CLT lacks the
`SwiftUIMacros` compiler plugin, so macro-based SwiftUI property wrappers
(`@State`, `@Environment`, `@Binding`, `@FocusState`, …) **fail to compile**.

Workarounds used in this codebase — do not reintroduce those macros:

- Model is a plain `let store: ScreenshotStore` passed down; the store is
  `@Observable` (ObservationMacros plugin *is* available) so views still
  update automatically.
- Shared view state (e.g. the "Copied" badge) lives in the store instead of
  `@State`.
- For genuinely view-local state (hover in `GhostIconButton`), write `State`
  storage manually instead of the macro:
  `private var _x = State(initialValue: false)` + `_x.wrappedValue`.
- Non-UI stored properties in the store are marked `@ObservationIgnored`.

## UI

shadcn-inspired styling lives in `Sources/SCRO/Views/Theme.swift`:
`Theme` colors (adaptive via `labelColor`/`windowBackgroundColor`),
`cardStyle()`, `PrimaryButtonStyle`, `OutlineButtonStyle`, `GhostIconButton`.
Use these instead of ad-hoc styling. Note: styles can't read
`@Environment(\.isEnabled)`, so pass `isEnabled` explicitly and keep the
`.disabled()` modifier for behavior.

## Conventions

- Keep it minimal: no third-party dependencies, no sandbox, no signing beyond
  ad-hoc (`codesign --sign -`).
- Generated artifacts are gitignored (`.build/`, `build/`, `*.app`,
  `AppIcon.icns`); `bundle.sh` regenerates the icon when it's missing.
  Never commit secrets, tokens, or machine-specific paths.
- History cap: `ScreenshotStore.maxCaptures = 50`; captures dir is
  `~/Library/Application Support/scro/captures`.
- Screenshot folder resolution honors `com.apple.screencapture` `location`
  pref, fallback `~/Desktop` (`ScreenshotStore.screenshotsFolder()`).
  Resolved once at launch; changing the macOS save location needs an app restart.
- New captures are auto-copied to the clipboard; detection is debounced at
  250ms with a 150ms write-stability gate (see `FolderWatcher`). The watcher
  runs on the main queue for actor-isolation correctness — don't move it to a
  background queue without explicit main-actor hops.
