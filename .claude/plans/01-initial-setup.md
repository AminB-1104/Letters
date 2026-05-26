# Phase 01 Implementation Plan — Letters

## Context

The Letters project is a fresh `flutter create` scaffold. All five required dependencies (`provider`, `go_router`, `dio`, `shared_preferences`, `flutter_dotenv`) are already in `pubspec.yaml`, but nothing is wired — `lib/` still contains only the default counter `main.dart`. The spec at `.claude/specs/01-initial-setup.md` defines a foundational architecture (folder structure, theme, routing, state, API service layer, env loading) for the Flutter side, plus a Node + Express + Mongo backend scaffold.

This plan implements both stacks per user direction:
- **Flutter**: replace the counter scaffold with the spec's folder structure and wire all five deps end-to-end, booting Splash → Home.
- **Backend**: scaffold inside `letters/server/` (sub-directory of this repo, per user choice), with Mongo connection, error middleware, JWT/bcrypt utilities, and a `GET /health` endpoint — **no business routes**.

Phase 01 ships infrastructure only — no auth flow, no messaging, no sockets.

## Flutter Plan

### A. Folder structure under `lib/`

Mirrors spec §4.1. All filenames use `snake_case` per §9.

```
lib/
├── core/
│   ├── constants/        route_names.dart, env_keys.dart
│   ├── theme/            app_theme.dart, app_colors.dart, app_text_styles.dart, app_spacing.dart
│   ├── utils/            result.dart (Result<T,E>), validators.dart (stub)
│   ├── services/         api_service.dart (Dio + interceptors), storage_service.dart (SharedPreferences)
│   └── widgets/          app_button.dart, app_text_field.dart, app_loader.dart,
│                         app_empty_state.dart, app_error_state.dart, app_scaffold.dart
├── models/               (empty; .gitkeep)
├── providers/            auth_provider.dart, user_provider.dart, app_settings_provider.dart
├── routes/               app_router.dart (GoRouter config)
├── screens/
│   ├── splash/           splash_screen.dart
│   └── home/             home_screen.dart
├── features/             (empty; .gitkeep — reserved for vertical slices in Phase 02+)
└── main.dart             rewritten
```

Rationale: `screens/` holds top-level routed pages; `features/` is reserved for future vertical slices (e.g. `features/chat/` will own its own widgets/providers/services). Both folders are mentioned in the spec but unexplained — this is the cleanest separation.

### B. `lib/main.dart` rewrite

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const LettersApp());
}
```

`LettersApp` wraps `MaterialApp.router` in a `MultiProvider` with the three providers, consumes `AppTheme.light()` and `AppRouter.config`.

### C. Theme (`core/theme/`)
- `app_colors.dart` — neutral palette constants (primary, surface, error, on*)
- `app_text_styles.dart` — `TextStyle` constants keyed by role (headline, body, caption)
- `app_spacing.dart` — `s4`, `s8`, `s12`, `s16`, `s24`, `radiusS`, `radiusM`
- `app_theme.dart` — `ThemeData light()` factory composing the above

No hardcoded colors anywhere outside this folder (spec §4.2 Rule 3).

### D. Routing (`routes/app_router.dart`)
- `GoRouter` with initial location `/splash`
- Routes: `/splash` → `SplashScreen`, `/home` → `HomeScreen`
- Route names centralized in `core/constants/route_names.dart`

### E. State (`providers/`) — all stubs per spec §7 ("structurally prepared")
- `AuthProvider extends ChangeNotifier` — `bool isAuthenticated => false`; `signIn()`/`signOut()` throw `UnimplementedError`
- `UserProvider extends ChangeNotifier` — `User? currentUser => null`
- `AppSettingsProvider extends ChangeNotifier` — `ThemeMode themeMode` with `toggleTheme()` (the one provider that actually does something visible in Phase 01)

### F. API service (`core/services/api_service.dart`)
- Single `Dio` instance, base URL from `dotenv.env['API_BASE_URL']`
- Request interceptor: attach `Authorization: Bearer <token>` if `StorageService` has one
- Response interceptor: map `DioException` → typed `ApiError`
- Exposes `get`/`post`/`put`/`delete` returning `Future<Result<T, ApiError>>` using `core/utils/result.dart`

UI never imports `dio` directly (spec §4.4).

### G. `flutter_dotenv` wiring
- Create `.env` (gitignored): `API_BASE_URL=http://localhost:3000`
- Create `.env.example` (committed): same key, empty value, documents the contract
- Add to `pubspec.yaml` under `flutter > assets`:
  ```yaml
  flutter:
    uses-material-design: true
    assets:
      - .env
  ```
- `dotenv.load()` runs in `main()` before `runApp` (see §B)

### H. Splash screen behavior
- `initState` schedules a future: when `dotenv` is loaded and `AppSettingsProvider` initialized (~1s minimum for visible splash), `go('/home')`
- This proves the async-init pattern Phase 02 will reuse for auth bootstrapping

### I. Test fixup
`test/widget_test.dart` currently asserts the counter increments. It will fail the moment `main.dart` is rewritten. Replace with a minimal smoke test that pumps `LettersApp` and verifies the splash renders (e.g. `expect(find.byType(SplashScreen), findsOneWidget)` after `pumpAndSettle` with mocked dotenv).

Note: `dotenv.load` reads from the asset bundle, which `flutter_test` doesn't populate. The smoke test will need either `dotenv.testLoad(fileInput: '...')` or to skip the dotenv call via a test flag in `main.dart`. Prefer `dotenv.testLoad` — no production code change.

## Backend Plan — `letters/server/`

### A. Initialization
- `npm init -y`
- Runtime deps: `express mongoose dotenv cors jsonwebtoken bcrypt`
- Dev deps: `nodemon`
- `package.json` scripts: `"start": "node server.js"`, `"dev": "nodemon server.js"`

### B. Folder structure (spec §5.1) — filenames in `kebab-case` (spec §9)

```
server/
├── config/             db.js (Mongo connect + retry), env.js (parsed env w/ validation)
├── controllers/        health-controller.js
├── middleware/         error-handler.js, auth-middleware.js (defined, NOT mounted)
├── models/             user-model.js (email, username, passwordHash, timestamps)
├── routes/             index.js (mounts /health), health-routes.js
├── services/           jwt-service.js (sign/verify), hash-service.js (bcrypt wrappers)
├── socket/             README.md ("Reserved for Phase 03 — do not implement")
├── utils/              async-handler.js, api-response.js (success/error helpers)
├── .env.example
├── .gitignore          (node_modules, .env)
├── package.json
└── server.js           loads env → connects Mongo → mounts routes → mounts error-handler → listens
```

### C. `.env` contract
```
PORT=3000
MONGO_URI=mongodb://localhost:27017/letters
JWT_SECRET=replace-me-in-production
```

### D. Response envelopes (spec §5.4) — `utils/api-response.js`
- `success(res, { data, message = 'Operation successful', status = 200 })` → `{success:true, message, data}`
- `error(res, { message, status = 500 })` → `{success:false, message}`

### E. Health endpoint
- `GET /health` → `success(res, { data: { uptime: process.uptime() } })`
- Confirms Express + error-handler + response envelope work end-to-end without needing Mongo data

### F. Auth scaffolding (spec §7 — structural only)
- `jwt-service.js` exports `sign(payload)`/`verify(token)` using `JWT_SECRET`
- `hash-service.js` exports `hash(plain)`/`compare(plain, hash)` using bcrypt with cost 12
- `auth-middleware.js` exports the middleware but **no route uses it**
- No `/login` or `/register` routes

## Root-level changes (Flutter repo)

- **`.gitignore`** — append:
  ```
  # env
  .env
  server/node_modules/
  server/.env
  ```
- **`analysis_options.yaml`** — add to keep the Dart analyzer off the Node tree:
  ```yaml
  analyzer:
    exclude:
      - server/**
  ```
- **`pubspec.yaml`** — add `assets: [.env]` under `flutter:` (see §G above)

## Critical files

**Modified:**
- `lib/main.dart` — full rewrite
- `pubspec.yaml` — add `flutter > assets`
- `.gitignore` — add env + server/node_modules entries
- `analysis_options.yaml` — exclude `server/**`
- `test/widget_test.dart` — replace counter test with splash smoke test

**Created (Flutter, ~22 files):** every file listed in §A under `lib/`, plus `.env` and `.env.example` at repo root

**Created (Backend, ~14 files):** every file listed in §B under `server/`

## Existing utilities to reuse

None — this is greenfield work. The only "existing" code is the default counter app (deleted) and the dependency stack already declared in `pubspec.yaml`.

## Verification

1. **Flutter static checks**
   - `flutter pub get`
   - `flutter analyze` → 0 issues
   - `flutter test` → smoke test passes (splash renders)

2. **Flutter runtime**
   - `flutter run -d windows`
   - Observe: splash visible ~1s, transitions to Home placeholder
   - Add a temp `print(dotenv.env['API_BASE_URL'])` in splash → confirm `.env` loaded
   - Tap a debug "toggle theme" button on Home → confirm `AppSettingsProvider` rebuilds the tree (proves provider is wired)
   - Remove the temp print and debug button before considering Phase 01 complete

3. **Backend runtime**
   - `cd server; npm install; npm run dev`
   - `curl http://localhost:3000/health` → `{"success":true,"message":"Operation successful","data":{"uptime":N}}`
   - Stop MongoDB → server logs retry attempts (proves `config/db.js` retry logic)
   - Hit an undefined route → standardized 404 error envelope (proves `error-handler` mounted)

4. **Hygiene**
   - `git status` shows neither `.env` nor `server/node_modules/` as untracked
   - `git diff --stat` shows only intended files

## Out of scope (deferred to Phase 02+)

- Login/register endpoints and screens
- Real API call from Flutter to backend (just `/health` ping is fine if curious, but not required)
- Sockets, messaging, friends, presence, media
- Production secret management, JWT refresh, rate limiting
- CI/CD, Docker, deployment configs

## Open assumptions

- **App branding** (name shown on Home, splash logo): using the literal string "Letters" with no logo asset. Trivial to swap later.
- **Theme palette**: starting with a neutral light theme (no brand color decided). Phase 02 can rebrand without touching anything outside `core/theme/`.
- **Mongo locally available** for backend smoke test. If it isn't, the server still boots and logs a retry loop — `/health` works without DB.
