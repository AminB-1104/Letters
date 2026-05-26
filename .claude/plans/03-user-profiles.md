# Phase 03 — User Discovery & Friend System

## Context

Phases 01–02 delivered the foundation (Flutter scaffold + Express/Mongo auth). Phase 03 layers the **social graph** on top: user search, friend requests (send/accept/decline), friends list, and basic profile previews. This is the first phase where relational state matters; chat and presence in later phases will read from it, so the data shape and service boundaries decided here are load-bearing.

Spec source: `.claude/specs/03-user-profiles.md`. The plan strictly follows the spec's structural rules (modular controllers/services, no widget→API calls, no realtime/messaging/uploads/notifications in scope).

---

## Delivery order

The spec prescribes step 1–7 (schema → backend logic → APIs → manual test → providers → screens → integration). The plan mirrors that order and breaks each step into self-contained commits per the spec's Rule 1/2 ("module-by-module, not one mega-response").

```
1. Backend: extend User schema
2. Backend: friend-service + user-service (pure logic, no HTTP)
3. Backend: controllers + routes + mount under /api
4. Manual API smoke test (curl)
5. Frontend: models + services
6. Frontend: providers
7. Frontend: screens + routes + home nav entry
```

---

## 1. Backend — User schema extension

**File:** `server/models/user-model.js` (modify in place; additive only)

Add the following fields to the existing schema (keep `timestamps: true`):

| Field | Type | Notes |
|---|---|---|
| `avatar` | `String` | default `''`. URL or empty. |
| `bio` | `String` | default `''`, `maxlength: 160`. |
| `friends` | `[ObjectId]` ref `User` | default `[]`. |
| `sentRequests` | `[ObjectId]` ref `User` | default `[]`. |
| `receivedRequests` | `[ObjectId]` ref `User` | default `[]`. |
| `blockedUsers` | `[ObjectId]` ref `User` | default `[]`. Reserved — no logic this phase. |
| `isOnline` | `Boolean` | default `false`. Reserved for presence; not toggled this phase. |
| `lastSeen` | `Date` | default `Date.now`. Reserved; not updated this phase. |

`username` already has a unique index (declared via `unique: true`) — no further index work required for Phase 03 search (the spec's "use indexed queries" is satisfied by the existing unique index on a lowercased field; search will use `RegExp` with anchor on this).

Existing users in the DB will simply have these arrays default to empty when read by Mongoose — no migration script needed.

---

## 2. Backend — Services

Mirror the existing `server/services/auth-service.js` style exactly: named-export functions, take destructured args (not `req`), throw via a `makeError(status, message)` helper with `err.expose = true`, and use a local `toPublicUser` / `toUserSummary` to shape outputs.

### 2.1 `server/services/user-service.js` (new)

Pure read-side service.

```
toUserSummary(doc)              // { id, username, displayName, avatar }
toPublicProfile(doc, viewerId)  // { id, username, displayName, avatar, bio, createdAt, friendCount, relationship }
searchUsers({ query, viewerId, page = 1, limit = 20 })
  - validate query (>=1 char after trim)
  - case-insensitive partial match on username (`new RegExp(escape(query), 'i')`)
  - filter out viewer (`_id: { $ne: viewerId }`)
  - `.select('username displayName avatar')`
  - `.skip((page-1)*limit).limit(limit)`
  - returns { results: [UserSummary], page, limit }
getProfileByUsername({ username, viewerId })
  - find by lowercase username; 404 if none
  - compute `relationship` ∈ {self, friend, requestSent, requestReceived, none}
  - return toPublicProfile
```

`relationship` derivation uses simple `.some(id => id.equals(viewerId))` checks against the target's `friends`/`receivedRequests`/`sentRequests` arrays.

Reuse the `escape` regex helper inline (a 1-liner) — no new dependency.

### 2.2 `server/services/friend-service.js` (new)

All relationship mutations; controller stays thin. Each mutator must enforce the spec's Rule 1–5 invariants atomically.

```
sendRequest({ fromUserId, toUserId })
  - 400 if fromUserId == toUserId               (Rule 1)
  - 404 if target user not found
  - 409 if already in fromUser.friends          (Rule 3)
  - 409 if already in fromUser.sentRequests     (Rule 2)
  - 409 if target already sent (then guide UX) — return 409 "Pending incoming request, accept instead"
  - $addToSet fromUser.sentRequests = targetId
  - $addToSet target.receivedRequests = fromUserId
acceptRequest({ userId, requesterId })         (Rule 4)
  - 404 if no incoming request from requesterId
  - $pull receivedRequests, $addToSet friends   (on user)
  - $pull sentRequests,     $addToSet friends   (on requester)
declineRequest({ userId, requesterId })        (Rule 5)
  - 404 if no incoming request
  - $pull receivedRequests (user) + sentRequests (requester)
removeFriend({ userId, friendId })
  - 404 if not in friends
  - $pull friends on both sides
listFriends({ userId, page = 1, limit = 50 })
  - load user, populate friends with select('username displayName avatar')
  - return paginated UserSummary[]
listRequests({ userId })
  - load user, populate receivedRequests + sentRequests with select('username displayName avatar')
  - return { incoming: UserSummary[], outgoing: UserSummary[] }
```

Validation rule: every incoming id is checked with `mongoose.Types.ObjectId.isValid(id)` at the top, throw `400 "Invalid user id"` otherwise (spec §10 Rule 3). Centralize via a small `assertObjectId(id, field)` helper inside the service file.

Use atomic `User.updateOne` with `$addToSet` / `$pull` rather than `findById → mutate → save` to avoid race conditions; that's the future-realtime-safe choice the spec calls for.

---

## 3. Backend — Controllers + routes

### 3.1 Controllers (thin, mirror `auth-controller.js`)

**`server/controllers/user-controller.js`** (new)

```
search   GET /api/users/search?q=&page=&limit=
profile  GET /api/users/profile/:username
```

Both wrap `asyncHandler`, validate request shape via the same `requireString` pattern used in `auth-controller.js`, then call `userService.*` and return via `success(res, { data, message })`.

**`server/controllers/friend-controller.js`** (new)

```
sendRequest    POST   /api/friends/send-request    { username | userId }
acceptRequest  POST   /api/friends/accept-request  { userId }
declineRequest POST   /api/friends/decline-request { userId }
removeFriend   POST   /api/friends/remove-friend   { userId }
listFriends    GET    /api/friends/list?page=&limit=
listRequests   GET    /api/friends/requests
```

All controllers read `req.user.id` (populated by `auth-middleware` — JWT payload `{ id, username }`).

Prefer accepting `userId` in the bodies (frontend already has it from search/list responses); the `send-request` endpoint additionally accepts `username` as a convenience for direct-link flows — service resolves it.

### 3.2 Routes

**`server/routes/user-routes.js`** (new)

```js
router.use(authMiddleware);                 // mount once at the top
router.get('/search', userController.search);
router.get('/profile/:username', userController.profile);
```

**`server/routes/friend-routes.js`** (new)

```js
router.use(authMiddleware);                 // every social route is protected (spec §10 Rule 1)
router.post('/send-request',    friendController.sendRequest);
router.post('/accept-request',  friendController.acceptRequest);
router.post('/decline-request', friendController.declineRequest);
router.post('/remove-friend',   friendController.removeFriend);
router.get ('/list',            friendController.listFriends);
router.get ('/requests',        friendController.listRequests);
```

**`server/routes/index.js`** (modify): add two `apiRouter.use(...)` lines next to the existing `/auth` mount.

```js
apiRouter.use('/users',   userRoutes);
apiRouter.use('/friends', friendRoutes);
```

Existing `middleware/error-handler.js` already maps `ValidationError`, dup-key `11000`, JWT errors, and `CastError` — no changes needed. `expose: true` errors from the services flow through unchanged.

---

## 4. Backend — Manual smoke test

After server reload, validate with `curl` from PowerShell (auth token from `/api/auth/login`):

```
# create two users A and B (existing /api/auth/register)
# A searches for B
curl "http://localhost:3000/api/users/search?q=bee" -H "Authorization: Bearer <A>"
# A views B's profile
curl "http://localhost:3000/api/users/profile/bee" -H "Authorization: Bearer <A>"
# A sends request to B
curl -X POST http://localhost:3000/api/friends/send-request -H "Authorization: Bearer <A>" -H "Content-Type: application/json" -d '{"userId":"<B-id>"}'
# duplicate → 409
# B lists requests
curl http://localhost:3000/api/friends/requests -H "Authorization: Bearer <B>"
# B accepts
curl -X POST http://localhost:3000/api/friends/accept-request -H "Authorization: Bearer <B>" -H "Content-Type: application/json" -d '{"userId":"<A-id>"}'
# both list friends
curl http://localhost:3000/api/friends/list -H "Authorization: Bearer <A>"
# A removes B
curl -X POST http://localhost:3000/api/friends/remove-friend -H "Authorization: Bearer <A>" -H "Content-Type: application/json" -d '{"userId":"<B-id>"}'
```

Exit criteria: every endpoint returns the standard envelope; the relationship rules (self, duplicate, accept-on-existing-friend) each return the expected 4xx code.

---

## 5. Frontend — Models

**`lib/models/user.dart`** (extend additively): add optional `avatar`, `bio` fields. Keep `fromJson`/`toJson` backwards-compatible (use `as String?` and skip nulls in `toJson`).

**`lib/features/social/models/user_summary.dart`** (new): lightweight shape for list contexts.

```dart
class UserSummary {
  final String id;
  final String username;
  final String displayName;
  final String? avatar;
  const UserSummary({required this.id, required this.username, required this.displayName, this.avatar});
  factory UserSummary.fromJson(Map<String, dynamic> j) => UserSummary(
    id: j['id'] as String,
    username: j['username'] as String,
    displayName: j['displayName'] as String,
    avatar: j['avatar'] as String?,
  );
}
```

**`lib/features/social/models/user_profile.dart`** (new): rich profile (used only by profile screen).

```dart
enum RelationshipStatus { self, friend, requestSent, requestReceived, none }

class UserProfile {
  final UserSummary user;
  final String bio;
  final DateTime? createdAt;
  final int friendCount;
  final RelationshipStatus relationship;
  ...
}
```

No `FriendRequest` model — incoming/outgoing request lists are just `List<UserSummary>` because the schema doesn't store per-request timestamps. If timestamps are needed later, switch to embedded sub-docs.

---

## 6. Frontend — Services

Mirror `lib/features/auth/services/auth_service.dart` exactly: take `ApiService` in the constructor, return `Future<Result<T, ApiError>>`, parse the `data` payload into typed models inside `fold(onSuccess: ...)`.

**`lib/features/social/services/user_service.dart`** (new)

```dart
class UserService {
  UserService(this._api);
  final ApiService _api;
  Future<Result<List<UserSummary>, ApiError>> search(String q, {int page = 1, int limit = 20});
  Future<Result<UserProfile,          ApiError>> profile(String username);
}
```

**`lib/features/social/services/friend_service.dart`** (new)

```dart
class FriendService {
  FriendService(this._api);
  final ApiService _api;
  Future<Result<void,                       ApiError>> sendRequest(String userId);
  Future<Result<void,                       ApiError>> acceptRequest(String userId);
  Future<Result<void,                       ApiError>> declineRequest(String userId);
  Future<Result<void,                       ApiError>> removeFriend(String userId);
  Future<Result<List<UserSummary>,          ApiError>> listFriends({int page = 1, int limit = 50});
  Future<Result<({List<UserSummary> incoming, List<UserSummary> outgoing}), ApiError>> listRequests();
}
```

Bearer-token injection is automatic via the existing `ApiService` interceptor (`lib/core/services/api_service.dart:39-47`). The envelope `{ success, data, message }` is already unwrapped by `ApiService._request` (line 80-81) — services receive `data` directly.

---

## 7. Frontend — Providers

Mirror `lib/features/auth/providers/auth_provider.dart`: `ChangeNotifier` + `enum {idle, loading, success, failure}` + `_error` + `notifyListeners()` after every state change. Keep each provider scoped — no "MegaProvider" (spec §7 Rule 3).

### 7.1 `lib/features/social/providers/user_provider.dart` (new — discovery)

State: `searchStatus`, `List<UserSummary> searchResults`, `profileStatus`, `UserProfile? selectedProfile`, `String? error`.
Methods: `search(q)`, `loadProfile(username)`, `clearSearch()`, `clearError()`.

### 7.2 `lib/features/social/providers/friend_provider.dart` (new)

State: `listStatus`, `List<UserSummary> friends`, `requestsStatus`, `List<UserSummary> incoming`, `List<UserSummary> outgoing`, per-action `Set<String> busyUserIds` for tile-level spinners, `String? error`.
Methods: `loadFriends()`, `loadRequests()`, `sendRequest(id)`, `accept(id)`, `decline(id)`, `remove(id)`. After a successful mutation, optimistically update the local lists (move user between `incoming` ↔ `friends`, drop from search via event) and `notifyListeners` — avoid a full refetch round-trip.

### 7.3 `lib/features/social/providers/social_provider.dart` (new — coordination only)

Holds a derived `Map<String userId, RelationshipStatus>` recomputed from `FriendProvider`'s friends/incoming/outgoing lists. Search tiles read from it to render the correct CTA (Add / Pending / Accept / Friends) without each tile making its own API call. Implemented as a `ChangeNotifier` that listens to `FriendProvider` via a constructor-injected callback / `addListener`.

Per the spec, `social_provider` is intentionally thin in Phase 03 — it exists as the coordination seam for Phase 04+ (presence, chat permissions). Do **not** put feature logic into it.

### 7.4 Existing `lib/providers/user_provider.dart` — repurpose

The current top-level `UserProvider` is a 19-line stub (`setUser` / `clearUser`) that's registered in `MultiProvider` but never read — `AuthProvider.currentUser` is the source of truth. **Delete it** and its registration in `main.dart`, and remove the import. The new social `UserProvider` lives under `features/social/providers/` and has a different responsibility, so reusing the class name is fine.

---

## 8. Frontend — Wiring (`lib/main.dart`)

Construct new services + providers in `_LettersAppState.initState` and register them in `MultiProvider`. Order matters (downstream depends on upstream):

```
Provider<StorageService>
Provider<ApiService>
Provider<AuthService>
Provider<UserService>          ← new
Provider<FriendService>        ← new
ChangeNotifierProvider<AppSettingsProvider>
ChangeNotifierProvider<AuthProvider>
ChangeNotifierProvider<FriendProvider>   ← new (constructed with FriendService)
ChangeNotifierProvider<UserProvider>     ← repurposed (constructed with UserService)
ChangeNotifierProvider<SocialProvider>   ← new (subscribes to FriendProvider)
```

Dispose each new provider in `_LettersAppState.dispose()`.

---

## 9. Frontend — Routes (Shell + branches)

Home becomes a **`StatefulShellRoute.indexedStack`** with three branches (Search / Friends / Requests). The shell owns the persistent `BottomNavigationBar` + `AppBar` (theme toggle, logout). Each branch keeps its own scroll/list state when tabs switch.

**`lib/core/constants/route_names.dart`** (modify): add

```dart
static const String search        = 'search';
static const String friends       = 'friends';
static const String requests      = 'requests';
static const String userProfile   = 'user_profile';
static const String searchPath      = '/home/search';
static const String friendsPath     = '/home/friends';
static const String requestsPath    = '/home/requests';
static const String userProfilePath = '/u/:username';
```

Keep `homePath = '/home'` as the redirect target after login; the router resolves `/home` to the default branch (Friends) via an initial-location-on-shell or an explicit `redirect: (_, __) => RouteNames.friendsPath` on the `/home` parent route.

**`lib/routes/app_router.dart`** (modify):

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [GoRoute(path: '/home/search',   name: RouteNames.search,   builder: (_, __) => const SearchUsersScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/home/friends',  name: RouteNames.friends,  builder: (_, __) => const FriendsListScreen())]),
    StatefulShellBranch(routes: [GoRoute(path: '/home/requests', name: RouteNames.requests, builder: (_, __) => const FriendRequestsScreen())]),
  ],
),
GoRoute(
  path: RouteNames.userProfilePath,
  name: RouteNames.userProfile,
  builder: (_, state) => UserProfileScreen(username: state.pathParameters['username']!),
),
```

`_redirect` needs a small tweak: when `status == authenticated`, treat any path that **starts with** `/home` (or matches `/u/...`) as already-authenticated; only redirect from `/login`/`/signup`/`/splash` to `RouteNames.friendsPath` (the default tab). The current redirect compares to `homePath` exactly — generalize via `location.startsWith('/home') || location.startsWith('/u/')`.

---

## 10. Frontend — Screens (`lib/features/social/screens/`)

All screens use `AppScaffold`, `AppButton`, `AppTextField`, `AppLoader`, `AppEmptyState`, `AppErrorState`, and only `AppColors` / `AppTextStyles` / `AppSpacing` tokens.

### 10.1 `search_users_screen.dart`

Top: `AppTextField` with `prefixIcon: Icons.search`. Live search debounced ~300 ms (use a local `Timer`). Body: `Consumer<UserProvider>` switches on `searchStatus` → loader / `ListView.separated` of `UserListTile` / `AppEmptyState` / `AppErrorState`. Tile trailing CTA derives from `SocialProvider.relationshipMap[user.id]`. Tap tile → `context.goNamed(RouteNames.userProfile, pathParameters: {'username': u.username})`.

### 10.2 `user_profile_screen.dart`

Stateful, takes `username` via constructor. `initState` → `context.read<UserProvider>().loadProfile(username)`. Body: avatar + display name + `@username` + bio + member-since + friend count + a single CTA button whose label/handler depend on `profile.relationship`:

| relationship | CTA |
|---|---|
| `self` | (none — show "This is you") |
| `none` | "Add friend" → `friend.sendRequest` |
| `requestSent` | "Cancel request" (no endpoint yet → disable, label as "Pending") |
| `requestReceived` | "Accept" + "Decline" |
| `friend` | "Remove friend" with confirmation dialog |

### 10.3 `friend_requests_screen.dart`

Two sections: **Incoming** and **Outgoing** (collapsible or simple `Column` headers). Each row is a `FriendRequestTile` with Accept/Decline (incoming) or just Cancel-text (outgoing). Pull-to-refresh wraps the list. Empty state per section.

### 10.4 `friends_list_screen.dart`

`ListView.separated` of `UserListTile` with trailing overflow menu → "View profile" / "Remove". Remove triggers confirmation dialog. Pull-to-refresh.

### 10.5 Widgets (`lib/features/social/widgets/`)

- `user_list_tile.dart` — `UserSummary` + optional trailing builder; reused by Search, Friends list, Requests outgoing.
- `friend_request_tile.dart` — `UserSummary` + Accept/Decline callbacks, busy state.
- `profile_header.dart` — used only by `user_profile_screen.dart`.

Tile-level busy state reads from `FriendProvider.busyUserIds` so each tile spins independently while others remain interactive.

---

## 11. Home shell (BottomNavigationBar)

Replace `lib/screens/home/home_screen.dart` with **`HomeShell`** — a stateful widget that owns the persistent AppBar (title + theme toggle + logout) and a `BottomNavigationBar`. It receives the `StatefulNavigationShell` from go_router and delegates tab switching to it.

```
HomeShell
├── AppBar: title "Letters", actions: [ThemeToggle, Logout]
├── body : navigationShell  // indexed stack of the three branches
└── bottomNavigationBar: BottomNavigationBar
      items:
        BottomNavigationBarItem(icon: Icons.search,             label: 'Search')
        BottomNavigationBarItem(icon: Icons.people_outline,     label: 'Friends')
        BottomNavigationBarItem(icon: Icons.mark_email_unread,  label: 'Requests')
      currentIndex: navigationShell.currentIndex
      onTap: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)
```

The Phase 02 "Welcome, $displayName" copy is dropped — the AppBar title + the populated tabs convey the same orientation. The pre-Phase-03 `HomeScreen` widget is deleted (its responsibilities now live in `HomeShell` + the three tab screens).

Theme tokens: `AppColors.surface` for the nav background, `AppColors.primary` for selected item. Use `BottomNavigationBarType.fixed` (3 items).

`HomeShell` lives at `lib/screens/home/home_shell.dart` (kebab-equivalent: snake_case per project convention).

---

## 12. Cross-cutting

- **No new pub dependencies.** Avatars use `Image.network` directly with a placeholder fallback; introduce `cached_network_image` only when Phase 04 needs it.
- **Logout side-effect:** `AuthProvider.signOut` should clear social state. Approach: have `FriendProvider`/`UserProvider`/`SocialProvider` expose a `reset()` and call them from `AuthProvider.signOut` via a small `onSignOut` callback registered in `main.dart` — or simpler, have each provider listen to `AuthProvider` and reset itself when `status` becomes `unauthenticated`. The listener approach keeps `AuthProvider` ignorant of social. **Choose the listener approach.**
- **Spec §10 Rule 4 (no secret leakage):** every backend response goes through `toUserSummary` / `toPublicProfile`. Never return the raw Mongoose doc. `.select('-passwordHash')` as a belt-and-braces guard on queries that don't pass through the helpers.
- **Spec §13 Rule 1/2 (module-by-module):** one commit per logical chunk, e.g. (a) schema + services, (b) controllers + routes, (c) frontend models + services, (d) providers + wiring, (e) screens + routes + home nav. Easier review and matches the spec's mandate.

---

## 13. Verification

End-to-end with the dev stack running:

1. **Backend smoke** — re-run the curl sequence from §4 against a fresh Mongo and confirm all envelopes + status codes.
2. **`flutter analyze`** — must remain lint-clean (`flutter_lints` ruleset).
3. **`flutter test`** — existing `test/widget_test.dart` (splash smoke) must still pass. Optionally add a unit test per new service that wraps a mocked `ApiService` and asserts the parse paths.
4. **Manual app run** (`flutter run -d chrome`) with two browser profiles, against the local Express server:
   - register two users
   - user A searches for B → finds B → opens B's profile → sends request
   - user B opens Requests → sees incoming from A → accepts
   - both see each other in Friends
   - A removes B → both lists go empty
   - logout from A → confirm social state resets (no flash of stale friends on next login)
5. **Negative paths**: self-search excluded; duplicate request shows the 409 message; declining removes only the request, not friendships.

---

## Files at a glance

**New (backend):** `server/controllers/{user,friend}-controller.js`, `server/services/{user,friend}-service.js`, `server/routes/{user,friend}-routes.js`.
**Modified (backend):** `server/models/user-model.js`, `server/routes/index.js`.

**New (frontend):** `lib/features/social/{models,services,providers,screens,widgets}/...` (per §5–10), `lib/screens/home/home_shell.dart`.
**Modified (frontend):** `lib/models/user.dart`, `lib/core/constants/route_names.dart`, `lib/routes/app_router.dart` (introduce `StatefulShellRoute`; generalize redirect), `lib/main.dart`.
**Removed (frontend):** `lib/providers/user_provider.dart` (unused stub — repurposed under `features/social/`), `lib/screens/home/home_screen.dart` (replaced by `home_shell.dart`).
