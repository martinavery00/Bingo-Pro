# Bingo Pro

Bingo Pro is an offline Flutter app for designing, diversifying, and printing numeric bingo cards. It supports standard 75-ball bingo and custom 3×3 through 7×7 rule sets, with up to 18 cards grouped into independent sets of six.

For product decisions, architecture, invariants, platform constraints, and known gaps, see [`docs/PROJECT_CONTEXT.md`](docs/PROJECT_CONTEXT.md). Coding agents should also follow [`AGENTS.md`](AGENTS.md).

## Features

- Seeded, reproducible six-card coverage optimization
- Balanced number frequency and reduced card/pattern overlap
- Standard 75-ball rules and custom column ranges/free cells
- Tap-grid winning-pattern editor with rotation and reflection variants
- Whole-card and per-cell locks during regeneration
- Comfort, high-contrast, grayscale, ink-saver, and custom styles
- Bundled Atkinson Hyperlegible, Noto Sans, and Roboto Slab fonts
- A4/Letter vector PDF preview, sharing, and native printing
- Exact-size cards, configurable margins/gutters, cut marks, and a 50 mm calibration page
- Offline Drift/SQLite projects and checksummed `.bingopro` import/export

Coverage optimization reduces correlation between the cards played together. It does not guarantee a win or make an individual valid card inherently luckier.

## Toolchain

The project is pinned to Flutter 3.47.9 in `.fvmrc`.

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

On Windows, Flutter 3.47 native-asset hooks can mishandle workspace paths containing spaces. If that occurs, run commands through a temporary alias:

```powershell
subst X: "D:\ChatGPT\Bingo Pro"
X:\.tooling\flutter\bin\flutter.bat test --no-pub
subst X: /D
```

Android builds require an installed Android SDK. iOS compilation and signing require macOS with Xcode.

## Architecture

- `lib/domain`: serializable project types, contracts, pattern transforms, and the optimizer
- `lib/data`: Drift database, repository, and project archives
- `lib/features`: project list and five-step editor workflow
- `lib/printing`: vector PDF and calibration-page generation
- `test`: rules, patterns, optimization, lock, archive, font/PDF, and widget tests

Run `dart run build_runner build` whenever the Drift schema changes.

## Font licenses

The source font licenses are bundled under `assets/licenses/` and must remain with redistributed builds/source packages.
