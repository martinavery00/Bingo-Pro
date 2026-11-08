# Bingo Pro project context

## Documentation policy

Every repository change must keep this file and `AGENTS.md` current before handoff. This file records the resulting product state, implementation facts, constraints, verification baseline, and known gaps; `AGENTS.md` records the durable implementation, safety, platform, and verification guidance future agents must follow. Updates belong in the relevant sections rather than in chronological change logs, so both documents remain descriptions of the current repository.

## Product brief

Bingo Pro is a private, offline mobile tool for creating and printing numeric bingo cards. Its primary user plays six cards in a game and may prepare up to three independent six-card sets. The app helps diversify each active set, customize its appearance and physical print layout, and produce a vector PDF suitable for saving, sharing, or native printing.

The optimization claim must remain precise: every valid card has the same marginal probability under fair draws. Bingo Pro can improve a multi-card portfolio relative to a redundant set by balancing number use and reducing shared numbers/pattern requirements. It cannot guarantee a win or promise an advantage over equally optimized opponents.

Working app identity:

- Product name: Bingo Pro
- Flutter package: `bingo_pro`
- Android namespace/application ID: `com.bingopro.bingo_pro`
- Current version: `0.1.0+1`
- Targets: Android and iOS

## Current user experience

The app opens to a local project list. Creating or opening a project enters a four-destination workflow:

1. **Rules** — choose 1–18 cards, standard 75-ball rules, or a custom 3×3–7×7 grid with editable labels/ranges and free cells.
2. **Patterns** — use the default row/column/diagonal masks or draw named masks. Rotations and reflections are explicit; 90°/270° rotation is available only for square grids.
3. **Style** — select bundled fonts and presets or edit colors, inner/outer lines, free-space label, paper, orientation, margins, gutters, page grid, cut marks, and exact card dimensions.
4. **Cards** — validate and generate diversified sets, inspect one optimizer group of up to six cards at a time, open a full-screen card viewer, start or resume a local Play Set session, explicitly edit regeneration locks, review collapsed coverage details, reproduce the saved seed, generate a new batch, or open the print preview.

Before generation, Cards presents a compact rules/pattern/card-count summary and the validation or generation state. After generation, it prioritizes a responsive card overview with a set selector when the project contains more than six cards. Opening a card uses the full screen and supports swiping only within its optimizer set. The ordinary virtual viewer remains view-only: normal card and cell taps never record game state.

Play Set is a separate, explicit gameplay mode for one optimizer set of up to six cards. It opens on a Numbers tab that shows every configured column together; tapping the board records or removes called numbers and automatically marks every matching card. Uncalled numbers that would complete at least one one-away pattern are highlighted directly on the number board as puro numbers, keeping the picker compact without a separate hint panel. The last-called chip opens a read-only history of called numbers in chronological order. A separate Cards tab shows all cards in a compact responsive overview, with a readable swipeable detail view on tap. Completed patterns are celebrated without ending the game, and one resumable local session is autosaved per set. Free cells are visually neutral and excluded from pattern requirements; a pattern variant containing only free cells is ignored. Called-number order is retained, but marks and wins are always derived from the current calls.

Virtual cards preserve the generated values, column labels, free cells, set membership, and stable card identifiers, but use an accessibility-oriented screen treatment with larger type and strong contrast instead of reproducing the selected print theme. The vector PDF preview remains the print-faithful representation and the authority for exact layout and dimensions. Full-card and numbered-cell locks are available only through an explicit Edit locks mode so browsing cannot accidentally alter regeneration state.

Projects autosave locally. A project can be exported/imported as a checksummed, versioned `.bingopro` JSON archive. Imported projects receive a new ID so they do not overwrite local projects.

## Generation model

`CoverageCardGenerator` is deterministic for a fixed ruleset, pattern list, card count, seed, and lock state.

- Split the requested cards into independent groups of at most six.
- Validate rules, masks, quantity, locked ranges, and locked duplicates before optimization.
- For each column, fill unlocked positions from the least-used valid values while avoiding duplicates within a card. This gives the minimum attainable frequency spread when locks permit it.
- Run seeded local search by swapping unlocked values within the same column across cards.
- Minimize pairwise full-card intersection and pattern-mask overlap.
- Track and return the best state encountered; exploratory moves must never make the final result worse than the initial balanced set.
- Guarantee unique full-card signatures. If locks make uniqueness or valid completion impossible, fail with a specific conflict rather than altering locks.

For a complete standard six-card set, the ideal B/I/G/O frequency is exactly twice per number: each column contains 30 positions drawn from 15 values. N contains 24 numbered positions, so nine values appear twice and six appear once.

The displayed 0–100 score is a coverage indicator derived from pair and pattern overlap. It is not a winning probability.

## Architecture and data flow

The project follows a UI/domain/data split with Riverpod-managed editor state:

```text
Flutter screens/widgets
        ↓
ProjectEditor (Riverpod notifier)
        ↓
domain contracts
   ↙            ↘
Drift repository  coverage/PDF services
        ↓
local SQLite + explicit file export/print
```

Important types:

- `BingoProject`: complete saved project aggregate and schema version.
- `RuleSet`: dimensions, labels, non-overlapping column ranges, and free cells.
- `PatternDefinition`: exact mask plus optional transforms.
- `BingoCard` / `CardCell`: stable identification, positions, values, and lock state.
- `OptimizationReport`: coverage score, frequency data, pair overlap, pattern overlap, and truthful warning text.
- `CardThemeConfig`: bundled font, colors, labels, and inner/outer line weights.
- `PrintLayoutConfig`: paper, units, exact/auto sizing, margins, gutters, grid, and cut marks.
- `PlaySession`: local per-set called-number order and source signature; it is not part of the project archive.
- `PlayEvaluation`: derived marked cells, one-away patterns, and completed pattern variants.

The domain layer does not import Flutter. Heavy card generation runs through `compute` so the UI isolate remains responsive. PDF output is vector-based and uses the same bundled font assets as the on-screen preview.

## Persistence and compatibility

- Drift database schema version: 2.
- Project/archive schema version: 1.
- The database stores the project aggregate as JSON plus indexed identity/name/update metadata.
- Resumable play sessions are stored in a separate local Drift table keyed by project and set. They are deliberately excluded from `.bingopro` export/import.
- Archive checksums are SHA-256 over the encoded payload.
- Archive import validates the checksum, schema, card-count bounds, and rules before saving.
- Bundled font files and license texts under `assets/` are part of the distributable source and must remain together.

Schema changes require explicit migrations and compatibility tests. Do not reinterpret an existing field with new semantics without incrementing the appropriate schema version.

## Print and visual defaults

Default output is A4 portrait, metric, 10 mm margins, 4 mm gutters, and a 2×3 card grid so one six-card set occupies one page. Exact dimensions take priority over the requested page grid; the exporter reduces the effective row/column count if necessary and rejects a card larger than the printable area.

The default Comfort palette is intentionally low-saturation and low-ink:

- App background `#F4F1EA`
- Printed background `#FFFFFF`
- Text `#1F2933`
- Grid `#52606D`
- Header `#D9E7E5`, header text `#163B3F`
- Free cell `#F2E8CF`
- Accent `#2F6F6D`

Bundled fonts are Atkinson Hyperlegible, Noto Sans, and Roboto Slab. Do not replace these with runtime-downloaded fonts; offline preview/PDF parity is a product requirement.

## Quality baseline

The current baseline is:

- `flutter analyze`: clean.
- 37 automated tests: passing.
- Tests cover rules, transforms, 18-card validity/balance/uniqueness, reproducibility, score monotonicity, custom grid sizes, lock preservation, play evaluation/session persistence, archive tampering, bundled PDF fonts, PDF/calibration generation, performance, the home-screen empty state, and the four-destination Cards/viewer/play workflow.
- Default 18-card generation with ten line patterns completes within the three-second test target on the development host.
- Android debug APK builds successfully at `build/app/outputs/flutter-apk/app-debug.apk`.

For generator changes, prefer fixed seeds and invariant assertions over snapshotting exact card numbers unless the PRNG algorithm itself is intentionally part of compatibility.

## Host and platform constraints

- Flutter is pinned to 3.47.9; the local SDK is ignored under `.tooling/`.
- VS Code launches Flutter through an `X:` drive alias created by the pre-launch task. This avoids a Windows native-asset hook quoting bug caused by the space in the workspace path; keep the launch program, working directory, custom Flutter tool, and drive-mapping task on the same alias.
- Android builds currently use Gradle 8.14.3 with Android Gradle Plugin 8.11.1, the minimum versions accepted by Flutter 3.47.9. Flutter warns that support for these versions will be dropped in a future release; migrate to the Gradle 9/AGP 9 toolchain only after the pinned legacy Android plugins are compatible.
- The development workspace is on D: while the pub cache is on C:. Kotlin incremental compilation is disabled because its cache path conversion fails across drive roots.
- The global C: drive is full and contains an incomplete NDK 28.2 installation. The Android project is pinned to installed NDK 26.1.10909125, which successfully builds the current plugins but produces a preferred-version warning.
- `path_provider_android` is pinned to 2.2.17 to avoid its newer JNI/NDK toolchain requirement. Upgrade it together with the NDK/toolchain after storage is available and rerun native builds/tests.
- Flutter currently warns that `file_picker` applies the legacy Kotlin Gradle Plugin. Revisit this dependency when a compatible built-in-Kotlin release is available.
- iOS compilation, signing, and native print validation require macOS/Xcode and have not been executed on this Windows host.

## Explicit non-goals for v1

- Accounts, cloud synchronization, collaboration, analytics, ads, or remote services
- Bingo caller automation, random/managed number drawing, voice recognition, multiplayer session administration, or shared game synchronization
- Word/phrase/image bingo cards
- Claims of guaranteed or precisely quantified winning advantage
- Large organizer runs beyond 18 cards

## Known gaps before production release

- Replace debug Android release signing with a protected production signing configuration.
- Confirm the final application ID, store metadata, privacy disclosures, launcher icon, and splash branding.
- Build and test on iOS, including Files import/export, native print, and PDF sharing.
- Validate actual-size A4 and Letter output on representative physical printers using the calibration page.
- Complete manual accessibility QA with screen readers and large text on physical devices.
- Revisit the NDK/path-provider/file-picker pins once the Android SDK can be repaired or relocated off the full C: drive.
- Add CI on Android plus a macOS iOS lane so platform compilation is continuously verified.

