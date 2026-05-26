# Phase 02 — Authentication Setup: Implementation Plan

## Context

Phase 01 shipped a Flutter + Express foundation with placeholders where auth will live: `AuthProvider.signIn/signOut` throw `UnimplementedError`, the backend's `auth-middleware.js` is written but not mounted, and the only route is `GET /health`. Phase 02 turns the placeholders into a working end-to-end authentication system per `.claude/specs/02-authentication-setup.md`.

By the end of Phase 02, users can register, log in, stay logged in across app restarts, log out, and the backend has the three required routes (`POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`) backed by bcrypt hashing, JWT issuance, and middleware-gated access.

### Confirmed design decisions (from clarifying questions)

1. **Flutter layout**: vertical slice under `lib/features/auth/{providers,screens,services}`. `User` model and `UserProvider` stay at the top level (shared with future features).
2. **API prefix**: new `/api` router; mount auth under it. `/health` stays at root.
3. **Hash field name**: keep `passwordHash` in the Mongo schema (clearer than the spec's literal `password`).

### Schema migration vs spec

Spec drops `email` from the User document and adds `displayName`. Current model has `{ username, email, passwordHash, createdAt, updatedAt }`. We're dropping `email` entirely (login uses `username`) and adding `displayName`. Local Mongo can be wiped — no production data to migrate.

---

## Backend (`server/`)

### B1. Env: add `JWT_EXPIRES_IN`

- **`server/config/env.js`**: add `jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d'`. Don't make it required — fall back to `'7d'`.
- **`server/.env`** and **`server/.env.example`**: add `JWT_EXPIRES_IN=7d`.
- **`server/services/jwt-service.js`**: replace the hardcoded `DEFAULT_EXPIRES_IN = '7d'` with `env.jwtExpiresIn`. Keep the `sign(payload, { expiresIn })` override option for tests.

### B2. User model

- **`server/models/user-model.js`**: replace `email` field with `displayName` (required, trim, minlength 2, maxlength 30). Tighten `username` to maxlength 20 (spec). Keep `passwordHash` and `timestamps: true`.

### B3. Auth service (new)

- **`server/services/auth-service.js`** (new): the only file with business logic for auth. Functions:
  - `registerUser({ username, displayName, password })` — checks uniqueness on username, calls `hashService.hash`, creates the document, signs a JWT with payload `{ id, username }`, returns `{ user, token }`. Throws `409` (with `err.expose = true`) on duplicate username.
  - `loginUser({ username, password })` — finds user (lowercased), `hashService.compare`, throws `401` (`err.expose = true`) on bad creds, returns `{ user, token }`.
  - `getCurrentUser(userId)` — finds by `_id`, throws `404` if missing.
  - Use a small `toPublicUser(doc)` helper that strips `passwordHash` and `__v`, renames `_id` → `id`. Reused by all three.
- Controllers must not call `bcrypt`, `jsonwebtoken`, or `User` directly — only this service. (Spec §5.2.)

### B4. Auth controller (new)

- **`server/controllers/auth-controller.js`** (new): three thin handlers (`register`, `login`, `me`), each wrapped in `asyncHandler` (existing `utils/async-handler.js`). They call the auth service and shape the response via `utils/api-response.js`'s `success()`. No validation, no hashing here. Status codes: 201 register, 200 login, 200 me.
- Inline validation: each handler does basic shape checks (presence, type, length) before calling the service, throwing `err.status = 400; err.expose = true`. Keep this tiny — defer to Mongoose validators for the deeper checks (already in the model).

### B5. Auth routes (new) + `/api` mount

- **`server/routes/auth-routes.js`** (new):
  ```js
  router.post('/register', authController.register);
  router.post('/login', authController.login);
  router.get('/me', authMiddleware, authController.me);
  ```
  Mount the existing `middleware/auth-middleware.js` (currently unmounted) only on `/me`.
- **`server/routes/index.js`**: add an `apiRouter = express.Router()`, mount `apiRouter.use('/auth', authRoutes)`, then `router.use('/api', apiRouter)`. Leave `/health` mounted at root unchanged.

### B6. Error handler enhancement

- **`server/middleware/error-handler.js`**: add explicit handling before the generic path for:
  - `err.name === 'ValidationError'` (Mongoose) → 400 with the first validator message.
  - `err.code === 11000` (Mongo duplicate key) → 409 "Username already taken".
  - `err.name === 'JsonWebTokenError'` / `'TokenExpiredError'` → 401 (the auth-middleware already catches these, but keep this as a backstop).
  Leave the existing `err.expose` / status-based logic for the rest.

### B7. Smoke test

Manually verify with the running server (instructions in Verification section below).

---

## Frontend (`lib/`)

### F1. User model extension

- **`lib/models/user.dart`**: add `displayName` field, drop `email`, add `fromJson(Map<String, dynamic>)` factory and `toJson()`. Keep it a plain immutable class (no codegen) — matches existing style.

### F2. Validators

- **`lib/core/utils/validators.dart`**: add three statics matching spec §6 rules:
  - `username(String?)` — required, lowercase, 3–20 chars, `RegExp(r'^[a-z0-9_]+$')`.
  - `password(String?)` — required, min 6 chars (per spec).
  - `displayName(String?)` — required, 2–30 chars.
  - `confirmPassword(String?, String original)` — must match.

### F3. Route names

- **`lib/core/constants/route_names.dart`**: add `login`/`signup` names and paths.

### F4. AuthProvider — move + implement

- Move **`lib/providers/auth_provider.dart`** → **`lib/features/auth/providers/auth_provider.dart`**.
- Update import paths in `lib/main.dart`.
- Redesign state. Constructor takes `StorageService` and `AuthService` (new — see F5):
  - Fields: `User? _user`, `AuthStatus _status` (enum: `unknown` / `unauthenticated` / `authenticated`), `String? _error`.
  - Getters: `isAuthenticated => _status == AuthStatus.authenticated`, `status`, `currentUser`, `error`.
  - `Future<void> bootstrap()` — called from splash. Reads token from `StorageService`. If absent → `unauthenticated`. If present → calls `authService.me()`. On `Success` → set user, status authenticated. On `Failure` (any) → `storage.clearAuthToken()`, status unauthenticated.
  - `Future<bool> register({username, displayName, password})` — calls `authService.register(...)`. On success: save token via storage, set user, status authenticated, return true. On failure: set `_error`, return false.
  - `Future<bool> signIn({username, password})` — same pattern.
  - `Future<void> signOut()` — clear token, null user, status unauthenticated.
- **Important**: `_status` starts at `unknown` so the router can show splash until `bootstrap()` resolves. `notifyListeners()` after every state change.

### F5. AuthService (new)

- **`lib/features/auth/services/auth_service.dart`** (new): the only auth-feature file that touches `ApiService`. Thin wrapper:
  - `Future<Result<({User user, String token}), ApiError>> register({...})` → `POST /api/auth/register`.
  - `Future<Result<({User user, String token}), ApiError>> login({...})` → `POST /api/auth/login`.
  - `Future<Result<User, ApiError>> me()` → `GET /api/auth/me`.
- Each method posts the JSON body, parses `data.user` into `User.fromJson` and pulls `data.token`. Note: `ApiService._request` already unwraps `data` from the envelope, so the service receives the inner object directly.

### F6. UserProvider

- **`lib/providers/user_provider.dart`**: keep as-is. `AuthProvider.signIn/register/bootstrap` will call `context.read<UserProvider>().setUser(...)` — but providers can't read context. Instead, pass a `UserProvider` reference into `AuthProvider`'s constructor via `ProxyProvider`, or have `AuthProvider` expose its own `currentUser` and let the router read from `AuthProvider`.
- **Recommended**: have `AuthProvider` own `currentUser` directly (single source of truth) and either (a) keep `UserProvider` for non-auth user data we'll add later, or (b) drop it for now and reintroduce when needed. Going with (a) — keep `UserProvider` but don't couple it to auth. Less churn; spec §4.4 references `user_provider.dart` so it should stay.

### F7. Login + Signup screens

- **`lib/features/auth/screens/login_screen.dart`** (new):
  - `StatefulWidget` with a `GlobalKey<FormState>`, two `TextEditingController`s.
  - Uses `AppScaffold`, `AppTextField` (with validators), `AppButton` (with `isLoading` bound to a local `_isSubmitting` flag).
  - On submit: `formKey.currentState!.validate()`, then `context.read<AuthProvider>().signIn(...)`. On returned `false`, surface `authProvider.error` via `ScaffoldMessenger.of(context).showSnackBar`.
  - Footer link → `context.goNamed(RouteNames.signup)`.
- **`lib/features/auth/screens/signup_screen.dart`** (new): same pattern, four fields (username, displayName, password, confirm), uses `Validators.confirmPassword`.
- Dispose all controllers in `dispose()`.

### F8. SplashScreen → bootstrap-aware

- **`lib/screens/splash/splash_screen.dart`**: replace the bare 1200ms `Timer` with: `WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AuthProvider>().bootstrap())`. The router's redirect (F9) handles the actual navigation as soon as status flips off `unknown`. Keep the splash UI as-is (logo + tagline).
- The existing widget test boots into Splash without pumping the timer through, so this change is test-safe — `bootstrap()` will start but the test asserts what's on screen at first frame.

### F9. Router with redirect + refresh

- **`lib/routes/app_router.dart`**: significant rewrite.
  - `GoRouter.config` becomes a static method or builder that accepts `AuthProvider` (or change `AppRouter` to a non-static class instantiated once in `main.dart`).
  - Add `/login` and `/signup` routes pointing at the new screens.
  - Add `redirect: (context, state) { ... }`:
    - If `auth.status == unknown` → stay on `/splash`.
    - If unauthenticated and target is not `/login` or `/signup` → redirect to `/login`.
    - If authenticated and target is `/login`/`/signup`/`/splash` → redirect to `/home`.
  - Add `refreshListenable: auth` so navigation reacts to login/logout.
- **`lib/main.dart`**: build the router after the providers exist. Pattern: wrap `MaterialApp.router` in a `Consumer<AuthProvider>` (or use `Builder` inside `MultiProvider`) and pass the provider to `AppRouter(auth: auth).config`.

### F10. Home screen — logout

- **`lib/screens/home/home_screen.dart`**: add a logout `IconButton` (or PopupMenuButton) in the AppBar actions. On tap: `context.read<AuthProvider>().signOut()` (router redirect handles navigation). Optionally show `authProvider.currentUser?.displayName` in the title.

### F11. main.dart wiring

- Update imports for moved `auth_provider.dart`.
- Add `Provider<AuthService>` registration depending on `ApiService`.
- Update `ChangeNotifierProvider<AuthProvider>` to depend on `StorageService` AND `AuthService` (use `ChangeNotifierProxyProvider2` or read other providers in `create`).
- Build the router with the auth provider available.

### F12. Test fix

- **`test/widget_test.dart`**: currently asserts `find.byType(SplashScreen)`. After F8/F9, splash still shows on first frame, so the test should still pass. But once `bootstrap()` runs, `AuthService.me()` will hit Dio. The test uses an unreachable base URL — the call will fail and resolve to `unauthenticated`. That's fine, but to keep the test deterministic, don't `pumpAndSettle()` (the existing test only uses `pump()`, so we're safe). Add a comment noting why we don't settle.

---

## Critical files at a glance

**Backend — new:**
- `server/services/auth-service.js`
- `server/controllers/auth-controller.js`
- `server/routes/auth-routes.js`

**Backend — modified:**
- `server/config/env.js` (add `jwtExpiresIn`)
- `server/services/jwt-service.js` (read from env)
- `server/models/user-model.js` (replace `email` with `displayName`)
- `server/routes/index.js` (add `/api` mount)
- `server/middleware/error-handler.js` (Mongoose/JWT error mapping)
- `server/.env` + `server/.env.example` (add `JWT_EXPIRES_IN`)

**Frontend — new:**
- `lib/features/auth/services/auth_service.dart`
- `lib/features/auth/screens/login_screen.dart`
- `lib/features/auth/screens/signup_screen.dart`

**Frontend — moved:**
- `lib/providers/auth_provider.dart` → `lib/features/auth/providers/auth_provider.dart`

**Frontend — modified:**
- `lib/models/user.dart` (add `displayName`, `fromJson`/`toJson`, drop email)
- `lib/core/utils/validators.dart` (username, password, displayName, confirmPassword)
- `lib/core/constants/route_names.dart` (login, signup)
- `lib/routes/app_router.dart` (redirect + refreshListenable + new routes)
- `lib/screens/splash/splash_screen.dart` (call bootstrap)
- `lib/screens/home/home_screen.dart` (logout button)
- `lib/main.dart` (AuthService provider, router wiring)

**Reused existing utilities (do not reimplement):**
- `server/services/jwt-service.js` (sign/verify)
- `server/services/hash-service.js` (hash/compare)
- `server/utils/async-handler.js`
- `server/utils/api-response.js` (success/error envelopes)
- `server/middleware/auth-middleware.js` (already correct — just mount it)
- `lib/core/services/api_service.dart` (Dio + Result + Bearer interceptor already in place)
- `lib/core/services/storage_service.dart` (`getAuthToken` / `setAuthToken` / `clearAuthToken` already in place)
- `lib/core/utils/result.dart`
- `lib/core/widgets/app_text_field.dart`, `app_button.dart`, `app_scaffold.dart`

---

## Verification

### Backend, manual via curl/PowerShell

From `server/`:
```powershell
npm run dev
```
In a second shell:
```powershell
# Register
curl -X POST http://localhost:3000/api/auth/register `
  -H "Content-Type: application/json" `
  -d '{"username":"ameen","displayName":"Ameen","password":"secret123"}'
# → 201, body has { success:true, data:{ user:{...}, token:"..." } }

# Duplicate registration
# → 409 "Username already taken"

# Login
curl -X POST http://localhost:3000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"username":"ameen","password":"secret123"}'
# → 200 with token

# Login wrong password
# → 401 "Invalid credentials"

# /me without token
curl http://localhost:3000/api/auth/me
# → 401 "Authentication token missing"

# /me with token
curl http://localhost:3000/api/auth/me -H "Authorization: Bearer <token>"
# → 200 with user

# /me with tampered token → 401 "Invalid or expired token"

# Health still works
curl http://localhost:3000/health
# → 200
```

### Flutter, automated

```powershell
flutter analyze        # must be clean
flutter test           # widget_test.dart must still pass
```

### Flutter, manual end-to-end

```powershell
# Terminal 1: backend
cd server; npm run dev

# Terminal 2: app
flutter run -d chrome
```

Walk through:
1. Fresh launch → splash → login screen.
2. Tap "Sign up" → fill form → submit → land on home.
3. Tap logout → land on login.
4. Log in with the same creds → land on home.
5. Hot restart (`R`) → splash → home (token persisted).
6. Manually clear `auth_token` from localStorage / shared_prefs, hot restart → land on login.
7. Submit invalid creds → SnackBar with backend error message.

---

## Out of scope (per spec §2 Non-Goals)

Realtime sockets, messaging, friend system, media uploads, push notifications, group chats. Do not introduce `chat_provider.dart`, `socket_provider.dart`, or anything under `server/socket/` — that directory's README explicitly reserves it for Phase 03+.
