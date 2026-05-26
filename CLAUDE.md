# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Fresh `flutter create` scaffold. `lib/main.dart` is still the default counter app — there is no real architecture yet. Treat new feature work as greenfield, but use the dependency stack already chosen in `pubspec.yaml` (below) rather than introducing alternatives.

## Dependency stack (intended direction)

The following packages are added — prefer them over alternatives unless the user asks otherwise:

- **State management:** `provider` (chosen over Riverpod for this project — don't suggest switching).
- **Routing:** `go_router`
- **HTTP:** `dio`
- **Local storage:** `shared_preferences`
- **Env / secrets:** `flutter_dotenv` (load a `.env` file via `dotenv.load()` in `main` before `runApp`; add the asset to `pubspec.yaml` under `flutter > assets` and to `.gitignore`)

## Common commands

Run from the project root (`D:\Practice\Letters - Flutter\letters`):

```powershell
flutter pub get                 # fetch dependencies
flutter analyze                 # lint + static analysis (uses flutter_lints)
flutter test                    # run all tests
flutter test test/widget_test.dart  # run a single test file
flutter test --name "substring"     # run tests matching a name
flutter run -d chrome           # multiple devices exist (windows, chrome, edge) — always pass -d
flutter run -d windows
flutter build apk               # / appbundle / windows / web — Android tooling not yet verified here
```

`flutter run` without `-d` fails on this machine because Windows, Chrome, and Edge are all registered devices.

## Windows-specific gotchas

- **Developer Mode must be enabled** for plugin builds (shared_preferences and friends use symlinks). If you see `Building with plugins requires symlink support`, run `start ms-settings:developers` and toggle Developer Mode on. This already bit us once during initial setup.
- Shell is PowerShell — use `;` to chain, not `&&`; use `$env:VAR` not `$VAR`.

## Linting

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` with no customizations. Don't disable lints project-wide; suppress per-line/file with `// ignore:` / `// ignore_for_file:` if genuinely needed.
