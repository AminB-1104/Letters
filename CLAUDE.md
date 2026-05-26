# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phase 01 (foundation) is complete. Both stacks compile, lint clean, and pass smoke tests:

- **Flutter** (`lib/`): full folder structure, theme, router (go_router), providers (`provider`), Dio-based API service, dotenv wiring, Splash → Home flow. No real auth or messaging yet — those are stubs.
- **Backend** (`server/`): Express scaffold with Mongo connect-and-retry, error/404 middleware, standardized response envelopes, JWT + bcrypt utilities, `GET /health`. No business routes yet; auth middleware is defined but **not mounted**.

Spec for Phase 01 lives at `.claude/specs/01-initial-setup.md`; implementation plan at `.claude/plans/01-initial-setup.md`. Future phases follow the same spec/plan pattern under `.claude/specs/` and `.claude/plans/`.

## Architecture rules (do not violate)

Pulled from `.claude/specs/01-initial-setup.md`:

- **Widgets never call APIs directly.** Flow is `Widget → Provider → Service → API`. UI imports of `package:dio/...` are a red flag.
- **No hardcoded colors, text styles, or spacing outside `lib/core/theme/`.** All UI reads from `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme`.
- **Routes are centralized** in `lib/routes/app_router.dart`; route names/paths live in `lib/core/constants/route_names.dart`. Never hardcode a path string at a call site — use `context.goNamed(RouteNames.home)`.
- **One responsibility per file.** Splitting matters more than file count.
- **Filenames:** Dart files use `snake_case` (analyzer enforces); Node files in `server/` use `kebab-case`.

## Dependency stack (locked decisions — do not substitute)

- **State management:** `provider` (chosen over Riverpod — don't suggest switching).
- **Routing:** `go_router`
- **HTTP:** `dio` (only `lib/core/services/api_service.dart` imports it; UI uses the wrapper)
- **Local storage:** `shared_preferences` (wrapped in `lib/core/services/storage_service.dart`)
- **Env / secrets:** `flutter_dotenv` — `.env` is loaded in `main()` before `runApp`, declared as an asset in `pubspec.yaml`, and gitignored at repo root.

## Flutter layout (`lib/`)

```
lib/
├── core/
│   ├── constants/    route_names.dart, env_keys.dart
│   ├── theme/        app_theme.dart, app_colors.dart, app_text_styles.dart, app_spacing.dart
│   ├── utils/        result.dart (Result<T,E> sealed type), validators.dart
│   ├── services/     api_service.dart (Dio + interceptors + Result), storage_service.dart
│   └── widgets/      app_button, app_text_field, app_loader, app_empty_state,
│                     app_error_state, app_scaffold
├── models/           user.dart
├── providers/        auth_provider, user_provider, app_settings_provider (all ChangeNotifier)
├── routes/           app_router.dart (GoRouter config)
├── screens/
│   ├── splash/       splash_screen.dart (Timer-based bootstrap, cancels on dispose)
│   └── home/         home_screen.dart
├── features/         empty; reserved for vertical slices in Phase 02+
└── main.dart         loads dotenv → builds StorageService → MultiProvider → MaterialApp.router
```

Conventions:
- `screens/` holds top-level routed pages.
- `features/` is for future vertical slices (e.g. `features/chat/` will own its own widgets/providers/services).
- `AuthProvider.signIn()` and `signOut()` currently throw `UnimplementedError` — Phase 02 wires them up. `isAuthenticated` returns `false`.
- `AppSettingsProvider.toggleTheme()` is the one provider that does something visible in Phase 01 (theme button on Home).

## Backend layout (`server/`)

```
server/
├── config/      db.js (Mongo connect + retry every 5s), env.js (validates PORT/MONGO_URI/JWT_SECRET)
├── controllers/ health-controller.js
├── middleware/  error-handler.js (errorHandler + notFoundHandler), auth-middleware.js (DEFINED, NOT MOUNTED)
├── models/      user-model.js (username/email/passwordHash + timestamps)
├── routes/      index.js (mounts /health), health-routes.js
├── services/    jwt-service.js (sign/verify), hash-service.js (bcrypt cost=12)
├── socket/      README only — reserved for Phase 03+, do not implement
├── utils/       api-response.js (success/error envelopes), async-handler.js
└── server.js    env → db.connect → routes → notFound → errorHandler → listen
```

Response envelopes (don't deviate):

```js
// success
{ "success": true, "message": "...", "data": {...} }
// error
{ "success": false, "message": "..." }
```

Use `utils/api-response.js`'s `success(res, {data, message, status})` / `error(res, {message, status})` rather than handcrafting JSON. Use `utils/async-handler.js` to wrap any async controller so thrown errors reach `errorHandler`.

## Env files

Two `.env` files, both gitignored:
- **`.env`** (repo root) — Flutter app env. Currently only `API_BASE_URL`. Declared in `pubspec.yaml > flutter > assets`.
- **`server/.env`** — Node backend env: `PORT`, `MONGO_URI`, `JWT_SECRET`.

Both have committed `.env.example` siblings that document the contract.

## Common commands

Run from the project root (`D:\Practice\Letters - Flutter\letters`):

```powershell
# --- Flutter ---
flutter pub get                       # fetch dependencies
flutter analyze                       # lint + static analysis (uses flutter_lints)
flutter test                          # run all tests
flutter test test/widget_test.dart    # single test file
flutter test --name "substring"       # tests matching a name
flutter run -d chrome                 # always pass -d (windows, chrome, edge registered)
flutter run -d windows                # needs Visual Studio C++ workload installed
flutter build apk                     # / appbundle / windows / web — Android tooling not yet verified

# --- Backend (server/) ---
cd server
npm install                           # first-time setup
npm run dev                           # nodemon, hot reload
npm start                             # plain node server.js
curl http://localhost:3000/health     # sanity check (works with or without Mongo)
```

`flutter run` without `-d` fails on this machine because Windows, Chrome, and Edge are all registered devices.

`flutter run -d windows` requires the Visual Studio C++ desktop workload — if it errors with "Unable to find suitable Visual Studio toolchain", use `-d chrome` or `-d edge` instead, or install the workload via `flutter doctor`'s hint.

## Windows-specific gotchas

- **Developer Mode must be enabled** for plugin builds (shared_preferences and friends use symlinks). If you see `Building with plugins requires symlink support`, run `start ms-settings:developers` and toggle Developer Mode on. This already bit us once during initial setup.
- Shell is PowerShell — use `;` to chain, not `&&`; use `$env:VAR` not `$VAR`.
- `flutter run -d windows` additionally needs the Visual Studio "Desktop development with C++" workload installed.

## Linting

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. The only customization is `analyzer.exclude: [server/**]` so the Dart analyzer doesn't scan the Node tree.

Three files use `// ignore_for_file: prefer_initializing_formals` (with a comment explaining why) — keeping `storage` as the public named param name while binding to a private `_storage` field via the initializer list. Don't "fix" these by switching to `required this._storage` (that leaks the underscore to callers).

Don't disable lints project-wide; suppress per-line/file with `// ignore:` / `// ignore_for_file:` if genuinely needed, and explain why in a comment above the directive.

## Testing notes

- `test/widget_test.dart` is a splash smoke test. It calls `dotenv.loadFromString(envString: ...)` and `SharedPreferences.setMockInitialValues({})` so the app can boot without an asset bundle or real prefs.
- `flutter_dotenv` v6 uses `loadFromString`, **not** `testLoad` (which was renamed). The old name will fail with `undefined_method`.
- The splash screen schedules navigation via a `Timer` that's cancelled in `dispose`. Don't use `Future.delayed` for screen-transition delays — pending timers fail widget tests at teardown.
