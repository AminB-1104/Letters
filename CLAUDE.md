# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Phase 04 (chat system foundation — non-realtime) is complete. Both stacks compile, lint clean, and pass smoke tests:

- **Flutter** (`lib/`): full folder structure, theme, router (go_router) with auth-aware redirect and a `StatefulShellRoute` powering the post-auth `HomeShell` (BottomNavigationBar: **Chats / Friends / Requests** — Search moved off the tab bar to an AppBar icon). Vertical feature slices under `features/auth/`, `features/social/`, and `features/chat/`. Dio-based `ApiService` shared by all feature services. Provider tree with auth-status listener that resets social + chat providers on sign-out.
- **Backend** (`server/`): Express with Mongo connect-and-retry, error/404 middleware (Mongoose/JWT error mapping), standardized response envelopes, JWT + bcrypt utilities, `GET /health`, full auth API at `/api/auth/*`, the social API at `/api/users/*` and `/api/friends/*`, and the messaging API at `/api/chats/*` (create idempotent / list / detail) and `/api/messages/*` (send / paginated list). All non-auth routes are gated by `auth-middleware`. Sockets are NOT implemented — Phase 05.

Specs/plans:
- Phase 01: `.claude/specs/01-initial-setup.md` / `.claude/plans/01-initial-setup.md`
- Phase 02: `.claude/specs/02-authentication-setup.md` / `.claude/plans/02-authentication-setup.md`
- Phase 03: `.claude/specs/03-user-profiles.md` / `.claude/plans/03-user-profiles.md`
- Phase 04: `.claude/specs/04-chat-system-foundation.md` / `.claude/plans/04-chat-system-foundation.md`

Future phases follow the same spec/plan pattern under `.claude/specs/` and `.claude/plans/`.

## Architecture rules (do not violate)

- **Widgets never call APIs directly.** Flow is `Widget → Provider → Service → API`. UI imports of `package:dio/...` are a red flag. Feature-specific services (e.g. `lib/features/auth/services/auth_service.dart`) wrap `ApiService` and expose `Result<T, ApiError>`.
- **No hardcoded colors, text styles, or spacing outside `lib/core/theme/`.** All UI reads from `AppColors`, `AppTextStyles`, `AppSpacing`, `AppTheme`.
- **Routes are centralized** in `lib/routes/app_router.dart`; route names/paths live in `lib/core/constants/route_names.dart`. Never hardcode a path string at a call site — use `context.goNamed(RouteNames.search)`. For parameterised paths, use the helper (e.g., `RouteNames.userProfilePathFor(username)`) or `goNamed` with `pathParameters`.
- **Auth gating happens in the router**, not in screens. `AppRouter` takes an `AuthProvider`, uses it as `refreshListenable`, and redirects based on `AuthStatus.{unknown, unauthenticated, authenticated}`. Don't add `if (!authed) Navigator.push(...)` checks inside screens. The redirect treats any `/home*`, `/u/*`, or `/chat/*` path as authenticated-only.
- **Cross-feature reset on sign-out** is wired in `main.dart` via an `AuthProvider` listener that calls `reset()` on each feature provider (`UserProvider`, `FriendProvider`, `SocialProvider`, `ChatProvider`, `MessageProvider`) when status flips `authenticated → unauthenticated`. Feature providers must NOT take `AuthProvider` as a constructor dep — keep the dependency direction one-way. (`MessageProvider` does take `ChatProvider` as a constructor dep — that's a same-feature cross-provider link, not a cross-feature auth coupling.)
- **One responsibility per file.** Splitting matters more than file count.
- **Filenames:** Dart files use `snake_case` (analyzer enforces); Node files in `server/` use `kebab-case`.

Backend-specific:
- **Controllers stay thin.** They validate request shape and shape the response. All business logic — hashing, JWT signing, DB lookups — lives in `server/services/`. Controllers must not import `bcrypt`, `jsonwebtoken`, or Mongoose models directly.
- **Never expose `passwordHash`.** Use `auth-service.js`'s `toPublicUser()`, `user-service.js`'s `toUserSummary()` / `toPublicProfile()`, `chat-service.js`'s `toChatSummary()`, or an equivalent shaper before returning a user. `.select('username displayName avatar')` on queries that don't pass through a shaper.
- **Mutations on shared arrays / cross-doc state use atomic `$addToSet` / `$pull` / `updateOne`**, never `findById → mutate → save`. Friends use paired `User.updateOne` calls; the chat `lastMessage` update uses a single `Chat.updateOne({...}, { lastMessage })` (which also bumps `updatedAt` via the timestamps plugin so `/chats/list` re-sorts). This matters because Phase 05 will add realtime events on top.
- **Validate every incoming ObjectId** at the service boundary via the shared `assertObjectId(id, field)` helper (re-exported from `user-service.js`) — throws `400 "Invalid <field>"` for malformed input. Don't rely on the Mongoose `CastError` fallback for user-supplied ids.
- **Chat-specific invariants** (enforced in `chat-service.js` / `message-service.js`):
  - `participants` is stored sorted ascending by ObjectId string; the compound unique index on `(participants.0, participants.1)` then guarantees at most one chat per friend pair regardless of who initiated.
  - `POST /api/chats/create` is idempotent — returns `201` for new, `200` for existing, both with the same `chat` payload shape.
  - Chats can only be created between existing friends (`assertFriendship` — 403 otherwise).
  - Every message route validates participant membership via `chatService.assertParticipant({ userId, chatId })` (404 missing chat / 403 non-participant).
  - Message `content` is trimmed and length-bounded (1..2000) at the service layer. Storage is plain text; rendering is `Text(...)` (plain) in Flutter, so no HTML escape is performed server-side.

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
│   ├── constants/    route_names.dart (splash/login/signup/home + chats/friends/requests/
│   │                                    search/userProfile/chatScreen + path helpers),
│   │                 env_keys.dart
│   ├── theme/        app_theme.dart, app_colors.dart, app_text_styles.dart, app_spacing.dart
│   ├── utils/        result.dart (Result<T,E> sealed type),
│   │                 validators.dart (email, required, minLength, username, password,
│   │                                   displayName, confirmPassword)
│   ├── services/     api_service.dart (Dio + Bearer interceptor + Result), storage_service.dart
│   └── widgets/      app_button, app_text_field, app_loader, app_empty_state,
│                     app_error_state, app_scaffold (also accepts bottomNavigationBar)
├── features/
│   ├── auth/
│   │   ├── providers/  auth_provider.dart (status enum, bootstrap/signIn/register/signOut)
│   │   ├── services/   auth_service.dart (wraps ApiService for /api/auth/*)
│   │   └── screens/    login_screen.dart, signup_screen.dart
│   ├── social/
│   │   ├── models/     user_summary.dart, user_profile.dart (RelationshipStatus enum),
│   │   │               friend_requests_bundle.dart
│   │   ├── providers/  user_provider.dart (search + profile, debounced + stale-query guard),
│   │   │               friend_provider.dart (friends/requests + optimistic mutations +
│   │   │                                     busyUserIds per-tile spinner set),
│   │   │               social_provider.dart (derived relationshipMap; listens to FriendProvider)
│   │   ├── services/   user_service.dart, friend_service.dart (wrap ApiService)
│   │   ├── screens/    search_users_screen.dart (own AppScaffold — top-level route, no longer
│   │   │                                          a tab; "Message" entry added to friends_list
│   │   │                                          and user_profile when relationship == friend),
│   │   │               friends_list_screen.dart, friend_requests_screen.dart,
│   │   │               user_profile_screen.dart
│   │   └── widgets/    user_avatar.dart, user_list_tile.dart, friend_request_tile.dart,
│   │                   profile_header.dart
│   └── chat/
│       ├── models/     chat.dart (Chat + MessagePreview; `other` is the non-viewer participant —
│       │                          backend already derives it), message.dart (isMine(viewerId) helper)
│       ├── providers/  chat_provider.dart (chat list + createOrOpenChat + touchChatWithMessage
│       │                                    for in-place reorder; busyUserIds for tile spinners),
│       │               message_provider.dart (single-chat scope: openChat/loadMore/sendMessage/
│       │                                       closeChat; depends on ChatProvider for preview hoist)
│       ├── services/   chat_service.dart, message_service.dart (wrap ApiService)
│       ├── screens/    chat_list_screen.dart, chat_screen.dart (reverse ListView + bottom input)
│       └── widgets/    chat_tile.dart, message_bubble.dart, message_input.dart, relative_time.dart
├── models/           user.dart (id, username, displayName, avatar?, bio?, createdAt + fromJson/toJson)
├── providers/        app_settings_provider.dart (ChangeNotifier)
├── routes/           app_router.dart (GoRouter + redirect + refreshListenable + StatefulShellRoute)
├── screens/
│   ├── splash/       splash_screen.dart (calls AuthProvider.bootstrap on first frame)
│   └── home/         home_shell.dart (persistent AppBar with Search/theme/logout actions +
│                                     BottomNavigationBar wrapping the StatefulNavigationShell)
└── main.dart         loads dotenv → builds StorageService → StatefulWidget owns
                      Api/Auth/User/Friend/Chat/Message services +
                      Auth/Settings/User/Friend/Social/Chat/Message providers +
                      AppRouter → MultiProvider → MaterialApp.router →
                      AuthProvider listener resets feature providers on sign-out
```

Conventions:
- `features/` holds vertical slices. Each slice owns its `providers/`, `services/`, `screens/`, `widgets/`, and (where useful) `models/`. Slices are mostly independent — the **one allowed cross-slice import** is `features/chat/` reusing `UserSummary` from `features/social/models/user_summary.dart`, because `UserSummary` is the canonical "thin user" shape and we don't want a parallel chat-flavoured copy. No other cross-slice imports — wire everything else via the top-level `main.dart`.
- `screens/` holds top-level routed pages that don't belong to a feature slice (splash, the home shell).
- `lib/providers/` holds top-level, cross-feature state that has no natural feature home (currently just `AppSettingsProvider`). `AuthProvider` lives under `features/auth/providers/` because it's auth-owned, but it's still registered at the top of the `MultiProvider` tree because the router and home shell depend on it.
- The router is built once in `_LettersAppState.initState` against the eagerly-constructed `AuthProvider`. Don't reconstruct `AppRouter` on rebuilds — it would lose navigation state. The home tabs live inside a `StatefulShellRoute.indexedStack` so each branch keeps its scroll/list state when switching. Screens outside the shell (Search, UserProfile, ChatScreen) must provide their own `AppScaffold` + `AppBar` because they don't inherit anything from `HomeShell`.
- Feature providers expose a `reset()` method and are reset from `main.dart` on sign-out (see "Cross-feature reset on sign-out" rule above). Don't replicate this logic per-screen.
- Social + chat feature providers (`UserProvider`, `FriendProvider`, `ChatProvider`, `MessageProvider`) share the `SocialStatus { idle, loading, success, failure }` enum (declared in `features/social/providers/user_provider.dart` and re-imported by chat providers). Mirror this shape for new feature providers rather than inventing per-feature status enums. (`AuthProvider` predates this and uses its own `AuthStatus` enum because it also needs the `unknown` boot state.)
- `MessageProvider` is **single-chat-scoped** — it tracks one `currentChatId` + its messages list, not a `Map<chatId, ...>`. `openChat` resets the state; `closeChat` clears it. Don't introduce a multi-chat cache here without a real requirement (Phase 05 sockets will own that).

### Auth flow (Flutter side)

```
Splash → AuthProvider.bootstrap()
  → token present? GET /api/auth/me
  → success → AuthStatus.authenticated → router redirects to /home/chats (default branch)
  → failure → clear token → AuthStatus.unauthenticated → /login
  → no token → AuthStatus.unauthenticated → /login

Login/Signup → AuthProvider.signIn/register
  → on Success: save token via StorageService.setAuthToken,
                set currentUser, status authenticated → router pushes /home/chats
  → on Failure: set error string, screen shows SnackBar

Logout → AuthProvider.signOut
  → StorageService.clearAuthToken, status unauthenticated → router pushes /login
  → main.dart's AuthProvider listener calls reset() on UserProvider, FriendProvider,
    SocialProvider, ChatProvider, MessageProvider — no stale data on next sign-in
```

`ApiService`'s request interceptor reads `StorageService.getAuthToken()` on every request and adds `Authorization: Bearer <token>` if present.

Routing layout:
- `/home` redirects to `/home/chats`.
- Tab branches inside the `StatefulShellRoute`: `/home/chats`, `/home/friends`, `/home/requests`.
- Top-level routes that push *over* the shell (no bottom nav while open, back returns to the originating tab): `/home/search` (the AppBar search icon), `/u/:username` (profile), `/chat/:chatId` (conversation).
- The AppBar search icon on `HomeShell` `goNamed`s the search route; tile taps in Chats / Friends / etc. `goNamed` into `/chat/:id` or `/u/:username`. Never hardcode these paths at a call site — use `RouteNames` constants / helpers (`RouteNames.chatScreenPathFor(id)` etc.).

## Backend layout (`server/`)

```
server/
├── config/      db.js (Mongo connect + retry every 5s),
│                env.js (validates PORT/MONGO_URI/JWT_SECRET; JWT_EXPIRES_IN optional, default 7d)
├── controllers/ health-controller.js, auth-controller.js (register/login/me),
│                user-controller.js (search/profile),
│                friend-controller.js (send/accept/decline/remove/list/listRequests),
│                chat-controller.js (create/list/detail; create returns 201 new / 200 existing),
│                message-controller.js (send/list)
├── middleware/  error-handler.js (errorHandler + notFoundHandler; maps Mongoose ValidationError,
│                                  Mongo dup-key 11000, JWT errors → 400/409/401),
│                auth-middleware.js (mounted on /api/auth/me, all of /api/users/*, /api/friends/*,
│                                    /api/chats/*, and /api/messages/*)
├── models/      user-model.js (username 3–20 lowercase, displayName 2–30, passwordHash,
│                               avatar, bio (≤160), friends/sentRequests/receivedRequests/
│                               blockedUsers (ObjectId refs to User), isOnline, lastSeen,
│                               timestamps),
│                chat-model.js (participants [2 × ObjectId User, sorted ascending],
│                               lastMessage (ObjectId Message, default null), timestamps;
│                               compound unique index on (participants.0, participants.1) +
│                               multikey index { participants, updatedAt:-1 }),
│                message-model.js (chatId, sender, content (1..2000, trim),
│                                  type enum ['text','image','voice','file'] default 'text',
│                                  timestamps; compound index { chatId, createdAt:-1 })
├── routes/      index.js (mounts /health at root; /api/auth, /api/users, /api/friends,
│                          /api/chats, /api/messages under /api),
│                health-routes.js, auth-routes.js, user-routes.js, friend-routes.js,
│                chat-routes.js, message-routes.js
├── services/    jwt-service.js (sign with env.jwtExpiresIn / verify),
│                hash-service.js (bcrypt cost=12),
│                auth-service.js (registerUser/loginUser/getCurrentUser + toPublicUser),
│                user-service.js (searchUsers/getProfileByUsername + toUserSummary/
│                                 toPublicProfile + assertObjectId helper),
│                friend-service.js (send/accept/decline/remove + list + listRequests +
│                                   resolveUserId; atomic $addToSet/$pull on both sides),
│                chat-service.js (createOrGetChat — sorts pair + idempotent;
│                                 listChats — sorted by updatedAt desc, populated;
│                                 getChatById / assertParticipant; assertFriendship;
│                                 toChatSummary derives `other` from viewerId),
│                message-service.js (sendMessage — 400 on empty/>2000, 403 non-participant;
│                                    listMessages — newest→oldest paginated;
│                                    updates Chat.lastMessage via atomic updateOne)
├── socket/      README only — reserved for Phase 05 (realtime / presence), do not implement
├── utils/       api-response.js (success/error envelopes), async-handler.js
└── server.js    env → db.connect → routes → notFound → errorHandler → listen
```

`blockedUsers`, `isOnline`, and `lastSeen` exist on the schema as future-proofing for Phase 05+ — they are read-defaulted but never written. Chat creation does NOT consult `blockedUsers` yet. Do not implement blocking, presence, or last-seen logic until that phase.

Chat collection invariants the indexes assume:
- `participants` always stored with exactly 2 entries, sorted ascending by ObjectId string. `chat-service.js`'s `sortedPair` helper enforces this on every insert. Any future write path that creates a `Chat` document must use the same canonicalisation or the unique index will allow duplicates.
- `lastMessage` is a denormalisation for the chat-list query — never query the messages collection during `/api/chats/list`. The atomic `Chat.updateOne({_id}, { lastMessage })` inside `message-service.js#sendMessage` keeps it current and bumps `updatedAt` (via `{ timestamps: true }`) for re-sorting.

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

### Chat / Message endpoints (Phase 04)

All require `Authorization: Bearer <token>`.

| Method | Path | Body / Query | Status codes |
|--------|------|--------------|--------------|
| POST | `/api/chats/create` | `{ userId }` | 201 new / 200 existing / 400 / 401 / 403 / 404 |
| GET  | `/api/chats/list` | `?page=&limit=` (default `1` / `20`, max `50`) | 200 / 401 |
| GET  | `/api/chats/:chatId` | — | 200 / 400 / 401 / 403 / 404 |
| POST | `/api/messages/send` | `{ chatId, content }` | 201 / 400 / 401 / 403 / 404 |
| GET  | `/api/messages/:chatId` | `?page=&limit=` (default `1` / `30`, max `100`) | 200 / 400 / 401 / 403 / 404 |

Shapes:
- `ChatSummary = { id, other: UserSummary, lastMessage: MessagePreview | null, createdAt, updatedAt }` — the backend already picks the non-viewer participant and returns it as `other`, so the frontend never has to disambiguate.
- `MessagePreview = { id, sender: <userId>, content, type, createdAt }` — embedded inside `ChatSummary.lastMessage`.
- `Message = { id, chatId, sender: <userId>, content, type, createdAt }`.
- `chats/create` → `{ chat: ChatSummary }`. **Idempotent**: 201 on first creation, 200 on subsequent calls for the same pair; both return the same `chat` shape.
- `chats/list` → `{ results: ChatSummary[], page, limit }`, sorted by `updatedAt` desc.
- `chats/:chatId` → `{ chat: ChatSummary }`.
- `messages/send` → `{ message: Message }`.
- `messages/:chatId` → `{ results: Message[], page, limit }` ordered **newest → oldest** (`createdAt: -1`). The Flutter `ChatScreen` renders into a `reverse: true` `ListView` so the visual order is oldest→newest top-to-bottom.

Chat / message invariants (enforced in `chat-service.js` / `message-service.js`):
1. Users may only start chats with existing friends (`assertFriendship` — 403 otherwise).
2. At most one chat exists between any two users (`sortedPair` + compound unique index).
3. `POST /api/chats/create` is idempotent on the pair; never returns 409.
4. Messages can only be sent / listed by participants of the chat (`assertParticipant` — 403 non-participant, 404 missing chat).
5. `content` must be a non-empty string after trim and ≤ 2000 chars; otherwise 400 with `"Message cannot be empty"` / `"Message exceeds 2000 characters"`.
6. Only `type: 'text'` is written this phase, even though the enum reserves `image / voice / file` for future media work.

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

# chat smoke test (assumes A and B are already friends from the social smoke test)
# first call → 201 with new chat id
curl -X POST http://localhost:3000/api/chats/create `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"userId":"<B-id>"}'
# second call → 200, same chat id (idempotent)
curl -X POST http://localhost:3000/api/chats/create `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"userId":"<B-id>"}'
curl -X POST http://localhost:3000/api/messages/send `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"chatId":"<chat-id>","content":"hello"}'
curl http://localhost:3000/api/chats/list -H "Authorization: Bearer <B>"
curl "http://localhost:3000/api/messages/<chat-id>?page=1&limit=30" `
  -H "Authorization: Bearer <B>"
```

`flutter run` without `-d` fails on this machine because Windows, Chrome, and Edge are all registered devices.

`flutter run -d windows` requires the Visual Studio C++ desktop workload — if it errors with "Unable to find suitable Visual Studio toolchain", use `-d chrome` or `-d edge` instead, or install the workload via `flutter doctor`'s hint.

## Windows-specific gotchas

- **Developer Mode must be enabled** for plugin builds (shared_preferences and friends use symlinks). If you see `Building with plugins requires symlink support`, run `start ms-settings:developers` and toggle Developer Mode on. This already bit us once during initial setup.
- Shell is PowerShell — use `;` to chain, not `&&`; use `$env:VAR` not `$VAR`.
- `flutter run -d windows` additionally needs the Visual Studio "Desktop development with C++" workload installed.
- MongoDB is **not** part of the project install — you need a local `mongod` (or remote URI in `server/.env`'s `MONGO_URI`) before `/api/auth/*` endpoints will respond. `/health` works without it.
- **Physical-device runs need a reachable `API_BASE_URL`.** The repo-root `.env` defaults to `http://localhost:3000`, which on a phone resolves to the phone itself → all `/api/*` calls fail with `Connection Refused`. Switch to the dev machine's LAN IP (e.g. `http://192.168.0.176:3000` — discover via `Get-NetIPAddress -AddressFamily IPv4`) and ensure phone + PC share the same Wi-Fi. The backend already binds to `0.0.0.0` (Node default when `app.listen` omits the host arg), so no server change is needed. If the LAN IP still hangs, Windows Firewall is blocking inbound 3000 — run elevated: `New-NetFirewallRule -DisplayName "Letters Backend 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -Profile Private`. Verify from the phone's browser at `http://<lan-ip>:3000/health` before retrying sign-in. **Fully stop and re-run the Flutter app** after editing `.env` — `flutter_dotenv` loads once in `main()` and hot reload won't re-read it. USB-only alternative: keep `localhost` and run `adb reverse tcp:3000 tcp:3000` (must rerun after each reconnect).

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
