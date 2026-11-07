# Bingo Pro agent guidance

Read `docs/PROJECT_CONTEXT.md` before changing product behavior or architecture. Keep that document current when a change alters scope, invariants, platform constraints, schemas, or known gaps.

## Product invariants

- Bingo Pro is offline-first. Do not add accounts, analytics, network font loading, or cloud dependencies without an explicit product decision.
- A project contains 1–18 numeric cards. Cards are optimized independently in groups of at most six because six cards are played together in one game.
- Never describe the optimizer as guaranteeing a win or making one valid card inherently luckier. It balances number frequency and reduces overlap/correlation across the active set.
- Standard 75-ball cards use B: 1–15, I: 16–30, N: 31–45, G: 46–60, O: 61–75, with a free center.
- Custom grids remain within 3×3–7×7. Column ranges must not overlap and must contain enough values for each card.
- Regeneration must preserve every locked card/cell, maintain valid column ranges, and produce unique full cards or return a clear conflict.
- Exact print dimensions are authoritative. Reduce effective cards per page when necessary; never silently scale exact-size cards.
- Preserve bundled font licenses and keep PDF rendering offline.

## Architecture boundaries

- `lib/domain`: Flutter-independent models, contracts, mask transforms, and coverage optimization.
- `lib/data`: Drift persistence and checksummed `.bingopro` archives.
- `lib/app`: dependency providers and editor state orchestration.
- `lib/features`: widgets and the Rules → Patterns → Style → Generate → Review workflow.
- `lib/printing`: vector PDF construction and calibration output.
- UI code must call domain/data abstractions rather than duplicate generation, validation, persistence, or PDF rules.

When the Drift schema changes, increment `AppDatabase.schemaVersion`, add an explicit migration, and regenerate `lib/data/app_database.g.dart`. When the `.bingopro` payload changes incompatibly, increment and migrate the archive/project schema instead of silently accepting old data.

## Verification

Use the pinned Flutter version from `.fvmrc` (3.47.9). The repository-local SDK, when present, is `.tooling/flutter/bin/flutter.bat` and is intentionally ignored by Git.

Before handing off a behavioral change:

1. Run `flutter analyze --no-pub`.
2. Run the complete `flutter test --no-pub` suite.
3. For generator changes, cover fixed-seed reproducibility, validity, uniqueness, locks, score monotonicity, and the 18-card performance target.
4. For PDF/layout changes, test A4 and Letter geometry, exact sizing, pagination, fonts, and calibration output.
5. For persistence changes, test round trips, migrations, corruption, and future-version rejection.

On this Windows host, Flutter native-asset hooks can fail when the workspace path contains a space. Use a temporary drive alias for tests/builds and preserve the real test exit code:

```powershell
subst X: "D:\ChatGPT\Bingo Pro"
X:\.tooling\flutter\bin\flutter.bat test --no-pub
$testExit = $LASTEXITCODE
subst X: /D
exit $testExit
```

Do not delete or reset the global Android SDK to fix build issues. See the host-specific dependency/NDK notes in `docs/PROJECT_CONTEXT.md`.

