# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phase 03 (user discovery + friend system) is complete. Both stacks compile, lint clean, and pass smoke tests:

- **Flutter** (`lib/`): full folder structure, theme, router (go_router) with auth-aware redirect and a `StatefulShellRoute` powering the post-auth `HomeShell` (BottomNavigationBar: Search / Friends / Requests). Vertical feature slices under `features/auth/` and `features/social/`. Dio-based `ApiService` shared by all feature services. Provider tree with auth-status listener that resets social providers on sign-out.
- **Backend** (`server/`): Express with Mongo connect-and-retry, error/404 middleware (Mongoose/JWT error mapping), standardized response envelopes, JWT + bcrypt utilities, `GET /health`, full auth API at `/api/auth/*`, and the social API at `/api/users/*` (search + profile) and `/api/friends/*` (send / accept / decline / remove / list / requests). All social routes are gated by `auth-middleware`.

Specs/plans:
- Phase 01: `.claude/specs/01-initial-setup.md` / `.claude/plans/01-initial-setup.md`
- Phase 02: `.claude/specs/02-authentication-setup.md` / `.claude/plans/02-authentication-setup.md`
- Phase 03: `.claude/specs/03-user-profiles.md` / `.claude/plans/03-user-profiles.md`

Future phases follow the same spec/plan pattern under `.claude/specs/` and `.claude/plans/`.

## Architecture rules (do not violate)

- **Widgets never call APIs directly.** Flow is `Widget → Provider → Service → API`. UI imports of `package:dio/...` are a red flag. Feature-specific services (e.g. `lib/features/auth/services/auth_service.dart`) wrap `ApiService` and expose `Result<T, ApiError>`.
- **No hardcoded colors, text styles, or spacing outside `lib/core/theme/`.** All UI reads from `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme`.
- **Routes are centralized** in `lib/routes/app_router.dart`; route names/paths live in `lib/core/constants/route_names.dart`. Never hardcode a path string at a call site — use `context.goNamed(RouteNames.search)`. For parameterised paths, use the helper (e.g., `RouteNames.userProfilePathFor(username)`) or `goNamed` with `pathParameters`.
- **Auth gating happens in the router**, not in screens. `AppRouter` takes an `AuthProvider`, uses it as `refreshListenable`, and redirects based on `AuthStatus.{unknown, unauthenticated, authenticated}`. Don't add `if (!authed) Navigator.push(...)` checks inside screens. The redirect treats any `/home*` or `/u/*` path as authenticated-only.
- **Cross-feature reset on sign-out** is wired in `main.dart` via an `AuthProvider` listener that calls `reset()` on each feature provider (`UserProvider`, `FriendProvider`, `SocialProvider`) when status flips `authenticated → unauthenticated`. Feature providers must NOT take `AuthProvider` as a constructor dep — keep the dependency direction one-way.
- **One responsibility per file.** Splitting matters more than file count.
- **Filenames:** Dart files use `snake_case` (analyzer enforces); Node files in `server/` use `kebab-case`.

Backend-specific:
- **Controllers stay thin.** They validate request shape and shape the response. All business logic — hashing, JWT signing, DB lookups — lives in `server/services/`. Controllers must not import `bcrypt`, `jsonwebtoken`, or Mongoose models directly.
- **Never expose `passwordHash`.** Use `auth-service.js`'s `toPublicUser()`, `user-service.js`'s `toUserSummary()` / `toPublicProfile()`, or an equivalent shaper before returning a user. `.select('username displayName avatar')` on queries that don't pass through a shaper.
- **Mutations on relationship arrays use atomic `$addToSet` / `$pull`**, never `findById → mutate → save`. Two `User.updateOne` calls in parallel keep both sides of a relationship consistent without read-modify-write races. This matters because Phase 04 will add realtime events on top.
- **Validate every incoming ObjectId** at the service boundary via the shared `assertObjectId(id, field)` helper (re-exported from `user-service.js`) — throws `400 "Invalid <field>"` for malformed input. Don't rely on the Mongoose `CastError` fallback for user-supplied ids.

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
│   ├── constants/    route_names.dart (splash/login/signup/home + search/friends/requests/userProfile),
│   │                 env_keys.dart
│   ├── theme/        app_theme.dart, app_colors.dart, app_text_styles.dart, app_spacing.dart
│   ├── utils/        result.dart (Result<T,E> sealed type),
│   │                 validators.dart (email, required, minLength, username, password,
│   │                                   displayName, confirmPassword)
│   ├── services/     api_service.dart (Dio + Bearer interceptor + Result), storage_service.dart
│   └── widgets/      app_button, app_text_field, app_loader, app_empty_state,
│                     app_error_state, app_scaffold (now also accepts bottomNavigationBar)
├── features/
│   ├── auth/
│   │   ├── providers/  auth_provider.dart (status enum, bootstrap/signIn/register/signOut)
│   │   ├── services/   auth_service.dart (wraps ApiService for /api/auth/*)
│   │   └── screens/    login_screen.dart, signup_screen.dart
│   └── social/
│       ├── models/     user_summary.dart, user_profile.dart (RelationshipStatus enum),
│       │               friend_requests_bundle.dart
│       ├── providers/  user_provider.dart (search + profile, debounced + stale-query guard),
│       │               friend_provider.dart (friends/requests + optimistic mutations +
│       │                                     busyUserIds per-tile spinner set),
│       │               social_provider.dart (derived relationshipMap; listens to FriendProvider)
│       ├── services/   user_service.dart, friend_service.dart (wrap ApiService)
│       ├── screens/    search_users_screen.dart, friends_list_screen.dart,
│       │               friend_requests_screen.dart, user_profile_screen.dart
│       └── widgets/    user_avatar.dart, user_list_tile.dart, friend_request_tile.dart,
│                       profile_header.dart
├── models/           user.dart (id, username, displayName, avatar?, bio?, createdAt + fromJson/toJson)
├── providers/        app_settings_provider.dart (ChangeNotifier)
├── routes/           app_router.dart (GoRouter + redirect + refreshListenable + StatefulShellRoute)
├── screens/
│   ├── splash/       splash_screen.dart (calls AuthProvider.bootstrap on first frame)
│   └── home/         home_shell.dart (persistent AppBar + BottomNavigationBar wrapping the
│                                     StatefulNavigationShell from go_router)
└── main.dart         loads dotenv → builds StorageService → StatefulWidget owns
                      Api/Auth/User/Friend services + Auth/Settings/User/Friend/Social
                      providers + AppRouter → MultiProvider → MaterialApp.router →
                      AuthProvider listener resets feature providers on sign-out
```

Conventions:
- `features/` holds vertical slices. Each slice owns its `providers/`, `services/`, `screens/`, `widgets/`, and (where useful) `models/`. Slices are independent — `features/social/` does NOT import from `features/auth/` except via the top-level wiring in `main.dart`.
- `screens/` holds top-level routed pages that don't belong to a feature slice (splash, the home shell).
- `lib/providers/` holds top-level, cross-feature state that has no natural feature home (currently just `AppSettingsProvider`). `AuthProvider` lives under `features/auth/providers/` because it's auth-owned, but it's still registered at the top of the `MultiProvider` tree because the router and home shell depend on it.
- The router is built once in `_LettersAppState.initState` against the eagerly-constructed `AuthProvider`. Don't reconstruct `AppRouter` on rebuilds — it would lose navigation state. The home tabs live inside a `StatefulShellRoute.indexedStack` so each branch keeps its scroll/list state when switching.
- Feature providers expose a `reset()` method and are reset from `main.dart` on sign-out (see "Cross-feature reset on sign-out" rule above). Don't replicate this logic per-screen.
- Social feature providers (`UserProvider`, `FriendProvider`) share the `SocialStatus { idle, loading, success, failure }` enum (declared in `features/social/providers/user_provider.dart`). Mirror this shape for new feature providers rather than inventing per-feature status enums. (`AuthProvider` predates this and uses its own `AuthStatus` enum because it also needs the `unknown` boot state.)

### Auth flow (Flutter side)

```
Splash → AuthProvider.bootstrap()
  → token present? GET /api/auth/me
  → success → AuthStatus.authenticated → router redirects to /home/search (default branch)
  → failure → clear token → AuthStatus.unauthenticated → /login
  → no token → AuthStatus.unauthenticated → /login

Login/Signup → AuthProvider.signIn/register
  → on Success: save token via StorageService.setAuthToken,
                set currentUser, status authenticated → router pushes /home/search
  → on Failure: set error string, screen shows SnackBar

Logout → AuthProvider.signOut
  → StorageService.clearAuthToken, status unauthenticated → router pushes /login
  → main.dart's AuthProvider listener calls reset() on UserProvider,
    FriendProvider, SocialProvider — no stale data on next sign-in
```

`ApiService`'s request interceptor reads `StorageService.getAuthToken()` on every request and adds `Authorization: Bearer <token>` if present.

`/home` is a redirect-only route that forwards to `/home/search`; the three tab branches are `/home/search`, `/home/friends`, `/home/requests`. `/u/:username` is a top-level route that pushes over the shell (back navigation returns to the tab the user came from).

## Backend layout (`server/`)

```
server/
├── config/      db.js (Mongo connect + retry every 5s),
│                env.js (validates PORT/MONGO_URI/JWT_SECRET; JWT_EXPIRES_IN optional, default 7d)
├── controllers/ health-controller.js, auth-controller.js (register/login/me),
│                user-controller.js (search/profile),
│                friend-controller.js (send/accept/decline/remove/list/listRequests)
├── middleware/  error-handler.js (errorHandler + notFoundHandler; maps Mongoose ValidationError,
│                                  Mongo dup-key 11000, JWT errors → 400/409/401),
│                auth-middleware.js (mounted on /api/auth/me, all of /api/users/*,
│                                    and all of /api/friends/*)
├── models/      user-model.js (username 3–20 lowercase, displayName 2–30, passwordHash,
│                               avatar, bio (≤160), friends/sentRequests/receivedRequests/
│                               blockedUsers (ObjectId refs to User), isOnline, lastSeen,
│                               timestamps)
├── routes/      index.js (mounts /health at root; /api/auth, /api/users, /api/friends
│                          under /api),
│                health-routes.js, auth-routes.js, user-routes.js, friend-routes.js
├── services/    jwt-service.js (sign with env.jwtExpiresIn / verify),
│                hash-service.js (bcrypt cost=12),
│                auth-service.js (registerUser/loginUser/getCurrentUser + toPublicUser),
│                user-service.js (searchUsers/getProfileByUsername + toUserSummary/
│                                 toPublicProfile + assertObjectId helper),
│                friend-service.js (send/accept/decline/remove + list + listRequests +
│                                   resolveUserId; atomic $addToSet/$pull on both sides)
├── socket/      README only — reserved for Phase 04+ (chat / presence), do not implement
├── utils/       api-response.js (success/error envelopes), async-handler.js
└── server.js    env → db.connect → routes → notFound → errorHandler → listen
```

`blockedUsers`, `isOnline`, and `lastSeen` exist on the schema as future-proofing for Phase 04+ — they are read-defaulted but never written by Phase 03 code. Do not implement blocking, presence, or last-seen logic yet.

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

### Social endpoints (Phase 03)

All require `Authorization: Bearer <token>`.

| Method | Path | Body / Query | Status codes |
|--------|------|--------------|--------------|
| GET  | `/api/users/search` | `?q=&page=&limit=` | 200 / 400 / 401 |
| GET  | `/api/users/profile/:username` | — | 200 / 401 / 404 |
| POST | `/api/friends/send-request` | `{ userId }` or `{ username }` | 201 / 400 / 401 / 404 / 409 |
| POST | `/api/friends/accept-request` | `{ userId }` | 200 / 400 / 401 / 404 |
| POST | `/api/friends/decline-request` | `{ userId }` | 200 / 400 / 401 / 404 |
| POST | `/api/friends/remove-friend` | `{ userId }` | 200 / 400 / 401 / 404 |
| GET  | `/api/friends/list` | `?page=&limit=` | 200 / 401 |
| GET  | `/api/friends/requests` | — | 200 / 401 |

Shapes:
- `users/search` returns `{ results: UserSummary[], page, limit }` where `UserSummary = { id, username, displayName, avatar }`.
- `users/profile/:username` returns `{ user: { ...UserSummary, bio, createdAt, friendCount, relationship } }` where `relationship ∈ { self, friend, requestSent, requestReceived, none }`.
- `friends/list` returns `{ results: UserSummary[], page, limit }`.
- `friends/requests` returns `{ incoming: UserSummary[], outgoing: UserSummary[] }`.
- Mutation endpoints return `data: {}`.

Relationship invariants (enforced in `friend-service.js`):
1. A user cannot send a request to themselves.
2. A user cannot send a duplicate outgoing request.
3. A user cannot send a request to an existing friend.
4. Accepting moves the requester out of `receivedRequests`/`sentRequests` on both sides and into `friends` on both sides.
5. Declining only removes the request (no friendship side-effects).

When a target has already sent an incoming request, `/api/friends/send-request` returns 409 with `"This user already sent you a request — accept it instead"` rather than creating a duplicate.

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

# social smoke test (assumes two registered users A and B; <A>/<B> are JWTs)
curl "http://localhost:3000/api/users/search?q=bee" -H "Authorization: Bearer <A>"
curl http://localhost:3000/api/users/profile/bee   -H "Authorization: Bearer <A>"
curl -X POST http://localhost:3000/api/friends/send-request `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"userId":"<B-id>"}'
curl http://localhost:3000/api/friends/requests -H "Authorization: Bearer <B>"
curl -X POST http://localhost:3000/api/friends/accept-request `
  -H "Authorization: Bearer <B>" -H "Content-Type: application/json" `
  -d '{"userId":"<A-id>"}'
curl http://localhost:3000/api/friends/list -H "Authorization: Bearer <A>"
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

Several files use `// ignore_for_file: prefer_initializing_formals` (with a comment explaining why) — keeping the public named param name while binding to a private underscored field via the initializer list. Don't "fix" these by switching to `required this._foo` (that leaks the underscore to callers).

For unused callback parameters (e.g., `GoRoute.builder` ignoring `context` and `state`), use single `_` for each — `(_, _) => const Screen()`. The `unnecessary_underscores` lint flags `__` because Dart 3.7+ allows multiple unused parameters to share the `_` name as wildcards.

Don't disable lints project-wide; suppress per-line/file with `// ignore:` / `// ignore_for_file:` if genuinely needed, and explain why in a comment above the directive.

## Testing notes

- `test/widget_test.dart` is a splash smoke test. It calls `dotenv.loadFromString(envString: ...)` and `SharedPreferences.setMockInitialValues({})` so the app can boot without an asset bundle or real prefs. It asserts the splash renders on first frame — don't `pumpAndSettle()` here or the auth bootstrap network call will spin forever against the unreachable base URL.
- `flutter_dotenv` v6 uses `loadFromString`, **not** `testLoad` (which was renamed). The old name will fail with `undefined_method`.
- The splash screen now uses `WidgetsBinding.instance.addPostFrameCallback` to call `AuthProvider.bootstrap()` — not a `Timer`. Don't reintroduce timers for screen transitions; the router redirect handles navigation reactively via `refreshListenable`.

## Password reset on disk

Passwords are bcrypt-hashed (cost 12) and cannot be reversed. To overwrite a user's password without losing the account, run a one-off Node script that hashes the new value and calls `User.updateOne({ username }, { passwordHash })`. Don't expose a "reset password" endpoint without a verified channel (out of scope until later phases).
