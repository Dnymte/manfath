# Contributing to Manfath

Thanks for taking the time to dig in. Manfath is a small SwiftUI + AppKit
codebase — the whole app is a few thousand lines, deliberately readable.
PRs are welcome from anyone.

## Quick start

```sh
git clone https://github.com/Dnymte/manfath.git
cd manfath
brew install xcodegen
xcodegen generate
open Manfath.xcodeproj
```

The pure-logic tests don't need Xcode:

```sh
swift test
```

## Project layout

```
Manfath/
  App/        AppDelegate, ManfathApp, Info.plist, entitlements
  Core/       Value types: PortInfo, Enrichment, ProcessCategory, PortGroup, …
  Services/   Actors and providers (scanner, lsof, enrichment, tunnels)
  Stores/     @Observable view-models (PortStore, SettingsStore, TunnelStore)
  Views/      SwiftUI views (RootView, PortRow, InspectPanel, Settings/…)
  Resources/  Localizable.xcstrings (en + ar), Assets.xcassets (icon + brands)
ManfathTests/   XCTest suite — 137 tests at last count
Casks/          Homebrew Cask formula
Scripts/        release.sh + ExportOptions.plist + dmg-background renderer
web/            manfath.dev landing page (static html/css/js)
```

`ARCHITECTURE.md` is the source-of-truth design doc — read it before
touching the scanner / store / coordinator boundaries.

## Pull requests

1. Open an issue first if the change is more than ~50 lines or touches
   the scanner/enrichment pipeline. Easier to align early than to
   redo work.
2. Branch off `main`. Keep one logical change per PR.
3. Run `swift test` locally — CI will block the merge otherwise.
4. Match the existing code style (tight, unjudgmental comments only
   where the *why* isn't obvious from the names).
5. Update or add tests in `ManfathTests/` for any behaviour change in
   `Core/`, `Services/`, or `Stores/`.
6. UI changes: include a before/after screenshot in the PR description.
   Localization changes: update both `en` and `ar` in
   `Localizable.xcstrings`.

## Areas that are easy to land

- **More framework presets** — add to `PresetGroups.all` in
  `Manfath/Core/PresetGroups.swift`. If a brand isn't in
  [Simple Icons](https://simpleicons.org), use a sensible SF Symbol
  fallback in `BrandIcons.swift`.
- **More framework hints** — extend `FrameworkHint` and
  `FrameworkDetector` to recognize more dev servers from
  `package.json` deps or config files.
- **More database / system process names** — add to
  `CategoryClassifier.swift`.
- **Tunnel providers** — implement `TunnelProvider` and register in
  `TunnelRegistry.swift`. ngrok and Cloudflare Tunnel are the
  reference implementations.
- **Localizations** — Manfath ships en + ar today. Add new language
  columns to `Localizable.xcstrings`.

## Areas to discuss before working on

- **Scanner backend swap** — anything other than `lsof` requires
  thinking through sandbox + permission tradeoffs.
- **App Store distribution** — incompatible with `lsof`, will need a
  helper-tool architecture.
- **Auto-update mechanism** — Manfath ships via Homebrew Cask. New
  release flow plumbing (in-app banners, alternative update
  mechanisms, etc.) needs an issue first.

## Code of conduct

Be kind. Critique code, not people. We follow the
[Contributor Covenant](https://www.contributor-covenant.org/).
