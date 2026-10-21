<p align="center">
  <img src="docs/icon.png" width="120" alt="scro icon">
</p>

<h1 align="center">scro</h1>

<p align="center">
  <i>A tiny menu bar tray for your Mac screenshots — capture, browse, copy, drag.</i>
</p>

<p align="center">
  <a href="https://github.com/defficato/scro/releases/latest"><img src="https://img.shields.io/github/v/release/defficato/scro?color=6366f1" alt="latest release"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="Apache-2.0">
</p>

You already take screenshots with **⇧⌘4**. scro picks them up automatically,
keeps the last 50 in one place, and puts each new shot **on your clipboard the
moment it's taken** — so you can just ⌘V.

No cloud. No account. No editor you didn't ask for.

## Install

1. **[Download the latest DMG](https://github.com/defficato/scro/releases/latest)**
2. Open it and drag **scro** into **Applications**
3. Launch it — **right-click → Open** the first time (the app is ad-hoc
   signed, not notarized)

That's it. scro sits in your menu bar as a camera icon.

> If macOS says *"scro is damaged"*, run this once and open it again:
> ```sh
> xattr -dr com.apple.quarantine /Applications/scro.app
> ```

## Using it

Capture as usual: **⇧⌘4** (region) · **⇧⌘3** (screen) · **⇧⌘5** (options).
A second later the shot is in the panel **and already copied**.

| Do this | Get this |
|---|---|
| Click the menu bar icon | Panel with your latest screenshot |
| Click the preview, or **Copy** | Copied as an image *and* as a file |
| Drag the preview out | Drop it into Slack, Mail, Finder, anywhere |
| **‹ Prev / Next ›** | Browse older shots (newest first) |
| Click a filmstrip thumbnail | Jump straight to that shot |
| Folder icon | Reveal it in Finder |
| Trash icon | Clear history (your originals are untouched) |

The last **50** shots are kept automatically — older copies are cleaned up for
you.

## Command line (optional)

scro also ships a CLI for the same history:

```sh
/Applications/scro.app/Contents/MacOS/scro-cli install-cli   # one-time
```

| Command | Does |
|---|---|
| `scro list` | List captures (newest first) |
| `scro copy [n]` | Copy shot *n* to the clipboard (default: latest) |
| `scro path [n]` | Print its file path |
| `scro open [n]` | Reveal it in Finder |
| `scro count` · `scro clear` · `scro dir` | Count · wipe history · show folder |

*n is 1-based; `1` = most recent. Works even when the app is closed.*

## Good to know

- **Where are they saved?** Copies live in
  `~/Library/Application Support/scro/captures/`. Your originals stay wherever
  macOS put them (Desktop by default).
- **Want shots elsewhere?** ⇧⌘5 → Options → *Save to* — scro follows that
  setting (restart the app after changing it).
- **Only new shots are added**, i.e. taken while scro is running. History
  persists across restarts.
- **Start at login:** System Settings → General → Login Items → add scro.

## Build from source

macOS 14+ and a Swift 6 toolchain — Command Line Tools are enough, no Xcode.

```sh
./scripts/install-app.sh    # build + install to /Applications + CLI link
```

Prefer to just build? `./scripts/bundle.sh && open scro.app`.

<details>
<summary><b>Under the hood</b></summary>

- SwiftUI `MenuBarExtra` popover, Swift 6, zero third-party dependencies.
- Screenshot folder is watched with a `DispatchSource` file watcher; new files
  are copied in and auto-copied to the clipboard (~0.3–0.5s).
- The captures folder is the single source of truth — the app and the CLI are
  just two views of it (no IPC). Shared code lives in the `SCROCore` target.
- Releases are built with `./scripts/release.sh` (DMG + zip + checksums); CI
  builds both targets on every push.
</details>

## License

[Apache-2.0](LICENSE).
