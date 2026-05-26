# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phase 02 (authentication) is complete. Both stacks compile, lint clean, and pass smoke tests:

- **Flutter** (`lib/`): full folder structure, theme, router (go_router) with auth-aware redirect, providers (`provider`), Dio-based API service, dotenv wiring, Splash → Login/Signup → Home flow with persistent JWT sessions and logout.
- **Backend** (`server/`): Express with Mongo connect-and-retry, error/404 middleware (with Mongoose/JWT error mapping), standardized response envelopes, JWT + bcrypt utilities, `GET /health`, and a full auth API at `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me` (the last gated by `auth-middleware`).

Specs/plans:
- Phase 01: `.claude/specs/01-initial-setup.md` / `.claude/plans/01-initial-setup.md`
- Phase 02: `.claude/specs/02-authentication-setup.md` / `.claude/plans/02-authentication-setup.md`

Future phases follow the same spec/plan pattern under `.claude/specs/` and `.claude/plans/`.

## Architecture rules (do not violate)

- **Widgets never call APIs directly.** Flow is `Widget → Provider → Service → API`. UI imports of `package:dio/...` are a red flag. Feature-specific services (e.g. `lib/features/auth/services/auth_service.dart`) wrap `ApiService` and expose `Result<T, ApiError>`.
- **No hardcoded colors, text styles, or spacing outside `lib/core/theme/`.** All UI reads from `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme`.
- **Routes are centralized** in `lib/routes/app_router.dart`; route names/paths live in `lib/core/constants/route_names.dart`. Never hardcode a path string at a call site — use `context.goNamed(RouteNames.home)`.
- **Auth gating happens in the router**, not in screens. `AppRouter` takes an `AuthProvider`, uses it as `refreshListenable`, and redirects based on `AuthStatus.{unknown, unauthenticated, authenticated}`. Don't add `if (!authed) Navigator.push(...)` checks inside screens.
- **One responsibility per file.** Splitting matters more than file count.
- **Filenames:** Dart files use `snake_case` (analyzer enforces); Node files in `server/` use `kebab-case`.

Backend-specific:
- **Controllers stay thin.** They validate request shape and shape the response. All business logic — hashing, JWT signing, DB lookups — lives in `server/services/`. Controllers must not import `bcrypt`, `jsonwebtoken`, or Mongoose models directly.
- **Never expose `passwordHash`.** Use `auth-service.js`'s `toPublicUser()` (or an equivalent) to strip it before returning a user.

## Dependency stack (locked decisions — do not substitute)

- **State management:** `provider` (chosen over Riverpod — don't suggest switching).
- **Routing:** `go_router`
- **HTTP:** `dio` (only `lib/core/services/api_service.dart` imports it; UI uses the wrapper)
- **Local storage:** `shared_preferences` (wrapped in `lib/core/services/storage_service.dart`)
- **Env / secrets:** `flutter_dotenv` — `.env` is loaded in `main()` before `runApp`, declared as an asset in `pubspec.yaml`, and gitignored at repo root.
- **Backend auth:** `bcrypt` (NOT `bcryptjs`) cost 12; `jsonwebtoken` v9 with `JWT_EXPIRES_IN` from env (default `7d`).

## Flutter layout (`lib/`)

```
lib/
├── core/
│   ├── constants/    route_names.dart (splash/login/signup/home), env_keys.dart
│   ├── theme/        app_theme.dart, app_colors.dart, app_text_styles.dart, app_spacing.dart
│   ├── utils/        result.dart (Result<T,E> sealed type),
│   │                 validators.dart (email, required, minLength, username, password,
│   │                                   displayName, confirmPassword)
│   ├── services/     api_service.dart (Dio + Bearer interceptor + Result), storage_service.dart
│   └── widgets/      app_button, app_text_field, app_loader, app_empty_state,
│                     app_error_state, app_scaffold
├── features/
│   └── auth/
│       ├── providers/  auth_provider.dart (status enum, bootstrap/signIn/register/signOut)
│       ├── services/   auth_service.dart (wraps ApiService for /api/auth/*)
│       └── screens/    login_screen.dart, signup_screen.dart
├── models/           user.dart (id, username, displayName, createdAt + fromJson/toJson)
├── providers/        user_provider, app_settings_provider (both ChangeNotifier)
├── routes/           app_router.dart (GoRouter + redirect + refreshListenable)
├── screens/
│   ├── splash/       splash_screen.dart (calls AuthProvider.bootstrap on first frame)
│   └── home/         home_screen.dart (displays user, theme toggle, logout)
└── main.dart         loads dotenv → builds StorageService → StatefulWidget owns
                      Api/Auth services + AuthProvider + AppRouter →
                      MultiProvider → MaterialApp.router
```

Conventions:
- `features/` holds vertical slices. `auth` is the first one. Future ones (`features/chat/`, `features/friends/`) own their providers/services/screens/widgets.
- `screens/` holds top-level routed pages that don't belong to a feature slice (splash, home).
- `lib/providers/` holds top-level, cross-feature state (`UserProvider`, `AppSettingsProvider`). `AuthProvider` lives under `features/auth/providers/` because it's auth-owned, but it's still registered at the top of the `MultiProvider` tree because the router and home depend on it.
- The router is built once in `_LettersAppState.initState` against the eagerly-constructed `AuthProvider`. Don't reconstruct `AppRouter` on rebuilds — it would lose navigation state.

### Auth flow (Flutter side)

```
Splash → AuthProvider.bootstrap()
  → token present? GET /api/auth/me
  → success → AuthStatus.authenticated → router redirects to /home
  → failure → clear token → AuthStatus.unauthenticated → /login
  → no token → AuthStatus.unauthenticated → /login

Login/Signup → AuthProvider.signIn/register
  → on Success: save token via StorageService.setAuthToken,
                set currentUser, status authenticated → router pushes /home
  → on Failure: set error string, screen shows SnackBar

Logout → AuthProvider.signOut
  → StorageService.clearAuthToken, status unauthenticated → router pushes /login
```

`ApiService`'s request interceptor reads `StorageService.getAuthToken()` on every request and adds `Authorization: Bearer <token>` if present.

## Backend layout (`server/`)

```
server/
├── config/      db.js (Mongo connect + retry every 5s),
│                env.js (validates PORT/MONGO_URI/JWT_SECRET; JWT_EXPIRES_IN optional, default 7d)
├── controllers/ health-controller.js, auth-controller.js (register/login/me — thin handlers)
├── middleware/  error-handler.js (errorHandler + notFoundHandler; maps Mongoose ValidationError,
│                                  Mongo dup-key 11000, JWT errors → 400/409/401),
│                auth-middleware.js (mounted on /api/auth/me only)
├── models/      user-model.js (username 3–20 lowercase, displayName 2–30, passwordHash, timestamps)
├── routes/      index.js (mounts /health at root and /api/auth at /api),
│                health-routes.js, auth-routes.js
├── services/    jwt-service.js (sign with env.jwtExpiresIn / verify),
│                hash-service.js (bcrypt cost=12),
│                auth-service.js (registerUser/loginUser/getCurrentUser + toPublicUser)
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

### Auth endpoints

| Method | Path | Auth | Status codes |
|--------|------|------|--------------|
| POST | `/api/auth/register` | none | 201 / 400 / 409 |
| POST | `/api/auth/login` | none | 200 / 400 / 401 |
| GET | `/api/auth/me` | Bearer JWT | 200 / 401 / 404 |

`register` and `login` return `{ user, token }`; `me` returns `{ user }`. `user` never contains `passwordHash`.

### Error envelope mapping

`error-handler.js` normalises these before falling back to the generic path:
- Mongoose `ValidationError` → 400 with the first field's message.
- Mongo duplicate key (code `11000`) → 409 `"Username already taken"`.
- `JsonWebTokenError` / `TokenExpiredError` → 401 `"Invalid or expired token"`.
- `CastError` → 400 `"Invalid identifier"`.

To return a custom user-facing message, throw an Error with `err.status = N; err.expose = true; err.message = '...'`. Without `expose`, 5xx messages are replaced with `"Internal server error"`.

## Env files

Two `.env` files, both gitignored:
- **`.env`** (repo root) — Flutter app env. Currently only `API_BASE_URL`. Declared in `pubspec.yaml > flutter > assets`.
- **`server/.env`** — Node backend env: `PORT`, `MONGO_URI`, `JWT_SECRET`, `JWT_EXPIRES_IN` (optional; defaults to `7d`).

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

# auth smoke test
curl -X POST http://localhost:3000/api/auth/register `
  -H "Content-Type: application/json" `
  -d '{"username":"ameen","displayName":"Ameen","password":"secret123"}'
curl -X POST http://localhost:3000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"username":"ameen","password":"secret123"}'
curl http://localhost:3000/api/auth/me -H "Authorization: Bearer <token>"
```

`flutter run` without `-d` fails on this machine because Windows, Chrome, and Edge are all registered devices.

`flutter run -d windows` requires the Visual Studio C++ desktop workload — if it errors with "Unable to find suitable Visual Studio toolchain", use `-d chrome` or `-d edge` instead, or install the workload via `flutter doctor`'s hint.

## Windows-specific gotchas

- **Developer Mode must be enabled** for plugin builds (shared_preferences and friends use symlinks). If you see `Building with plugins requires symlink support`, run `start ms-settings:developers` and toggle Developer Mode on. This already bit us once during initial setup.
- Shell is PowerShell — use `;` to chain, not `&&`; use `$env:VAR` not `$VAR`.
- `flutter run -d windows` additionally needs the Visual Studio "Desktop development with C++" workload installed.
- MongoDB is **not** part of the project install — you need a local `mongod` (or remote URI in `server/.env`'s `MONGO_URI`) before `/api/auth/*` endpoints will respond. `/health` works without it.

## Linting

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. The only customization is `analyzer.exclude: [server/**]` so the Dart analyzer doesn't scan the Node tree.

Four files use `// ignore_for_file: prefer_initializing_formals` (with a comment explaining why) — keeping the public named param name while binding to a private underscored field via the initializer list. Don't "fix" these by switching to `required this._foo` (that leaks the underscore to callers).

Don't disable lints project-wide; suppress per-line/file with `// ignore:` / `// ignore_for_file:` if genuinely needed, and explain why in a comment above the directive.

## Testing notes

- `test/widget_test.dart` is a splash smoke test. It calls `dotenv.loadFromString(envString: ...)` and `SharedPreferences.setMockInitialValues({})` so the app can boot without an asset bundle or real prefs. It asserts the splash renders on first frame — don't `pumpAndSettle()` here or the auth bootstrap network call will spin forever against the unreachable base URL.
- `flutter_dotenv` v6 uses `loadFromString`, **not** `testLoad` (which was renamed). The old name will fail with `undefined_method`.
- The splash screen now uses `WidgetsBinding.instance.addPostFrameCallback` to call `AuthProvider.bootstrap()` — not a `Timer`. Don't reintroduce timers for screen transitions; the router redirect handles navigation reactively via `refreshListenable`.

## Password reset on disk

Passwords are bcrypt-hashed (cost 12) and cannot be reversed. To overwrite a user's password without losing the account, run a one-off Node script that hashes the new value and calls `User.updateOne({ username }, { passwordHash })`. Don't expose a "reset password" endpoint without a verified channel (out of scope until later phases).
