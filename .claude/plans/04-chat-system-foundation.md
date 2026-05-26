# Phase 04 — Chat System Foundation

## Context

Phases 01–03 delivered the foundation (Flutter scaffold, auth, social graph). Phase 04 layers the **messaging engine** on top: a `Chat` collection (one row per friend-pair), a `Message` collection (one row per message), the five REST endpoints listed in `.claude/specs/04-chat-system-foundation.md §5.1`, and the Flutter UI to drive them.

Phase 04 is **non-realtime by design** — sockets, typing indicators, delivery status, presence, media, and push are explicitly out of scope (spec §2 "Non-Goals"). Phase 05 will bolt sockets onto this surface; the data shape and service boundaries chosen here are load-bearing for that.

Spec source: `.claude/specs/04-chat-system-foundation.md`. The plan follows the spec's "Suggested Development Order" (§15) and its "Generate messaging modules separately" rule (§14 Rule 1/2): one logical commit per chunk, not one mega-commit.

**Confirmed UX decisions (asked up front):**

1. **Chats replaces Search as a bottom-nav tab.** The 3 tabs become **Chats / Friends / Requests**. Search moves to an AppBar icon on the home shell. This matches a messaging app's hierarchy of attention.
2. **`POST /api/chats/create` is idempotent.** If a chat already exists for the pair, the endpoint returns **200** with the existing chat in `data.chat`. Newly created chats return **201**. Frontend treats both as success and navigates straight to the chat screen.

---

## Delivery order

Matches spec §15 (Steps 1–9). One commit per row keeps reviews tractable and respects §14 Rule 2 ("do NOT generate the entire messaging system in one response").

| # | Commit | Scope |
|---|---|---|
| 1 | Backend models | `chat-model.js` + `message-model.js` + indexes |
| 2 | Backend services | `chat-service.js` + `message-service.js` |
| 3 | Backend controllers + routes + mount | thin controllers, `/api/chats/*` + `/api/messages/*` mounted |
| 4 | Backend smoke test | curl sequence (§4 of this plan) — manual, no code |
| 5 | Frontend models + services | `Chat`, `Message`, `ChatService`, `MessageService` |
| 6 | Frontend providers + wiring | `ChatProvider`, `MessageProvider`, `main.dart` MultiProvider + reset |
| 7 | Frontend routes + home-shell rework | new tab layout, AppBar search icon, chat-screen route |
| 8 | Frontend screens + widgets | `ChatListScreen`, `ChatScreen`, `MessageBubble`, `MessageInput`, `ChatTile` |
| 9 | Frontend integration touch-ups | "Send message" entry points from FriendsList + UserProfile |

---

## 1. Backend — Models

Both models live in `server/models/`, mirror the style of `user-model.js` ('use strict', `{ timestamps: true }`, named export of `mongoose.model(...)`).

### 1.1 `server/models/chat-model.js` (new)

```js
const chatSchema = new mongoose.Schema(
  {
    participants: {
      type: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
      required: true,
      validate: {
        validator: (arr) => Array.isArray(arr) && arr.length === 2,
        message: 'A private chat must have exactly two participants',
      },
    },
    lastMessage: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
      default: null,
    },
  },
  { timestamps: true }
);

// Compound unique index on the sorted pair — enforces "one chat between two users"
// at the DB level. Pair is always stored sorted (ascending by ObjectId string).
chatSchema.index({ 'participants.0': 1, 'participants.1': 1 }, { unique: true });

// Multikey index for the "list my chats" query (find by membership).
chatSchema.index({ participants: 1, updatedAt: -1 });
```

**Why sorted pair + positional index, not a multikey unique index:**
A unique constraint on the multikey `participants` array would forbid a user being in more than one chat ever — wrong. The positional compound index works because every insert canonicalises the pair sorted ascending; the service layer enforces that ordering before insert (`§2.1` below). Two users → exactly one (A, B) document, regardless of who initiated.

### 1.2 `server/models/message-model.js` (new)

```js
const messageSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chat',
      required: true,
      index: true,
    },
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
      minlength: 1,
      maxlength: 2000,
    },
    type: {
      type: String,
      enum: ['text', 'image', 'voice', 'file'],
      default: 'text',
    },
  },
  { timestamps: true }
);

// Primary read pattern: "newest messages in a chat" → compound index.
messageSchema.index({ chatId: 1, createdAt: -1 });
```

`type` is enum-constrained to the four spec-listed values but only `'text'` is written this phase. The other three are reserved schema-level so a future media upload phase can ship without a schema migration.

---

## 2. Backend — Services

Both services follow the existing `friend-service.js` style exactly: named exports, destructured args (not `req`), `makeError(status, msg)` helper with `err.expose = true`, no controller/HTTP awareness, use `assertObjectId` from `user-service.js`.

### 2.1 `server/services/chat-service.js` (new)

```
sortedPair(aId, bId)                 // [min, max] by ObjectId string — internal helper
assertFriendship(userId, otherId)    // 403 if otherId NOT in userId.friends (Rule 2)
toChatSummary(chatDoc, viewerId)     // { id, other: UserSummary, lastMessage|null, updatedAt, createdAt }
toMessagePreview(msgDoc)             // { id, sender: <id>, content, type, createdAt } for lastMessage embedding

createOrGetChat({ userId, otherUserId })
  - assertObjectId both
  - 400 if userId == otherUserId
  - assertFriendship(userId, otherUserId)             (Rule 2)
  - sort pair → [a, b]
  - findOne({ 'participants.0': a, 'participants.1': b })
      → if found, return { chat, created: false }
      → else Chat.create({ participants: [a, b] }), return { chat, created: true }
  - both branches populate participants (select 'username displayName avatar')
    and lastMessage before passing to toChatSummary

listChats({ userId, page = 1, limit = 20 })
  - assertObjectId userId
  - Chat.find({ participants: userId })
        .sort({ updatedAt: -1 })
        .skip / .limit
        .populate('participants', 'username displayName avatar')
        .populate({ path: 'lastMessage', select: 'sender content type createdAt' })
  - map → toChatSummary(doc, userId)
  - return { results: ChatSummary[], page, limit }

getChatById({ userId, chatId })
  - assertObjectId both
  - load chat, populate participants + lastMessage
  - 404 if missing
  - 403 if userId NOT in participants                  (Security Rule 2)
  - return toChatSummary(chat, userId)

assertParticipant({ userId, chatId })
  - assertObjectId both
  - chat = await Chat.findById(chatId).select('participants')
  - 404 if !chat
  - 403 if userId NOT in chat.participants
  - returns chat (for callers that want the doc)
```

`toChatSummary` derives `other` by picking the participant whose `_id` does NOT match `viewerId`. The frontend never gets the raw participants array — it gets the *other* user + the viewer is implicit. This keeps the chat tile rendering trivial and removes a class of "render-the-wrong-name" bugs.

Re-export `assertParticipant` for `message-service.js`.

### 2.2 `server/services/message-service.js` (new)

```
toMessage(doc)                        // { id, chatId, sender, content, type, createdAt }

sendMessage({ userId, chatId, content })
  - assertObjectId userId + chatId
  - validate content (trim, 1..2000)                  (Rules 4 + 5)
      throw 400 'Message cannot be empty'  / 'Message exceeds 2000 characters'
  - chat = await chatService.assertParticipant({ userId, chatId })  (Rule 3)
  - msg  = await Message.create({ chatId, sender: userId, content, type: 'text' })
  - await Chat.updateOne({ _id: chatId }, { lastMessage: msg._id })
        // touches updatedAt too (timestamps: true), which is what the
        // /chats/list ordering relies on.
  - return toMessage(msg)

listMessages({ userId, chatId, page = 1, limit = 30 })
  - assertObjectId userId + chatId
  - await chatService.assertParticipant({ userId, chatId })          (Rule 3)
  - safePage = max(1, intOr(1)); safeLimit = clamp(intOr(30), 1, 100)
  - docs = await Message.find({ chatId })
                        .sort({ createdAt: -1 })          // newest → oldest (spec §9)
                        .skip((safePage - 1) * safeLimit)
                        .limit(safeLimit)
                        .lean()
  - return { results: docs.map(toMessage), page, limit }
```

`updateOne({ lastMessage })` is atomic and bumps `updatedAt` via the timestamps plugin, so `/api/chats/list` automatically re-sorts after every send. No second `.save()` is needed and there's no read-modify-write race — same discipline as `friend-service.js`.

`content` is trimmed at the Mongoose layer (`trim: true`) plus rejected at the service if empty after trim — belt-and-braces. We do NOT escape HTML/markdown server-side; the frontend renders content as plain text via `Text(...)` widgets, so XSS surface is zero in Phase 04 (still safe when web build is in scope because Flutter web doesn't `innerHTML` user content). Sanitisation Rule §11.4 is satisfied by the trim + plain-text rendering combo. Document this in a one-liner comment in the service.

---

## 3. Backend — Controllers + Routes

### 3.1 Controllers — thin, mirror `friend-controller.js`

**`server/controllers/chat-controller.js`** (new)

```
create   POST /api/chats/create  { userId }  → { chat: ChatSummary }
list     GET  /api/chats/list?page=&limit=    → { results, page, limit }
detail   GET  /api/chats/:chatId              → { chat: ChatSummary }
```

`create` reads `userId` from body (the other party), calls `chatService.createOrGetChat({ userId: req.user.id, otherUserId: userId })`, returns:
- `status: 201, message: 'Chat created'` when service returns `created: true`
- `status: 200, message: 'Chat already exists'` when `created: false`

**`server/controllers/message-controller.js`** (new)

```
send  POST /api/messages/send       { chatId, content }  → { message: Message }
list  GET  /api/messages/:chatId?page=&limit=            → { results, page, limit }
```

Both wrap `asyncHandler`, read `req.user.id` from `auth-middleware`, and shape responses via `success(res, { data, message, status })`. **Zero business logic.**

### 3.2 Routes

**`server/routes/chat-routes.js`** (new)

```js
router.use(authMiddleware);                              // §11 Rule 1
router.post('/create',     chatController.create);
router.get ('/list',       chatController.list);
router.get ('/:chatId',    chatController.detail);
```

**`server/routes/message-routes.js`** (new)

```js
router.use(authMiddleware);
router.post('/send',       messageController.send);
router.get ('/:chatId',    messageController.list);
```

**`server/routes/index.js`** (modify): add two lines under the existing apiRouter.

```js
apiRouter.use('/chats',    chatRoutes);
apiRouter.use('/messages', messageRoutes);
```

Existing `middleware/error-handler.js` already handles `ValidationError` (400), `CastError` (400), JWT errors (401), and forwards `expose: true` service errors — no changes needed.

---

## 4. Backend — Manual smoke test (Spec §15 Step 6)

After `npm run dev`, with two registered+friended users A and B:

```powershell
# A creates a chat with B (first time → 201)
curl -X POST http://localhost:3000/api/chats/create `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"userId":"<B-id>"}'

# A creates again (idempotent → 200, same chat id)
curl -X POST http://localhost:3000/api/chats/create `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"userId":"<B-id>"}'

# A sends a message
curl -X POST http://localhost:3000/api/messages/send `
  -H "Authorization: Bearer <A>" -H "Content-Type: application/json" `
  -d '{"chatId":"<chat-id>","content":"hello"}'

# B lists chats — sees one with lastMessage set
curl "http://localhost:3000/api/chats/list" -H "Authorization: Bearer <B>"

# B lists messages
curl "http://localhost:3000/api/messages/<chat-id>?page=1&limit=30" `
  -H "Authorization: Bearer <B>"

# Negative paths:
#   - empty content                 → 400 "Message cannot be empty"
#   - content >2000 chars           → 400 "Message exceeds 2000 characters"
#   - non-friend create             → 403
#   - non-participant /messages/:id → 403
#   - invalid ObjectId              → 400 "Invalid chat id"
```

Exit criteria: every endpoint returns the standard envelope; the relationship/length rules each return the expected 4xx code; the second `create` call returns the same `chat.id` as the first.

---

## 5. Frontend — Models

**`lib/features/chat/models/chat.dart`** (new)

```dart
class Chat {
  final String id;
  final UserSummary other;            // the *other* participant — backend computes it
  final MessagePreview? lastMessage;
  final DateTime updatedAt;
  final DateTime createdAt;
  // fromJson tolerates missing lastMessage (null on fresh chats).
}

class MessagePreview {
  final String senderId;
  final String content;
  final String type;                  // 'text' for Phase 04
  final DateTime createdAt;
}
```

**`lib/features/chat/models/message.dart`** (new)

```dart
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;
  // convenience getter `isMine(currentUserId)` for bubble alignment.
}
```

Reuse the existing `UserSummary` model from `lib/features/social/models/user_summary.dart` — no duplication. Chat models import `package:letters/features/social/models/user_summary.dart`. This is the one explicit cross-feature import the project allows because `UserSummary` is the canonical "thin user" shape.

---

## 6. Frontend — Services

Mirror `lib/features/social/services/friend_service.dart` exactly: constructor takes `ApiService`, return `Future<Result<T, ApiError>>`, parse inside `fold(onSuccess: ...)`.

**`lib/features/chat/services/chat_service.dart`** (new)

```dart
class ChatService {
  ChatService(this._api);
  final ApiService _api;
  Future<Result<Chat,        ApiError>> createChat(String otherUserId);  // POST /api/chats/create
  Future<Result<List<Chat>,  ApiError>> listChats({int page = 1, int limit = 20});
  Future<Result<Chat,        ApiError>> getChat(String chatId);
}
```

**`lib/features/chat/services/message_service.dart`** (new)

```dart
class MessageService {
  MessageService(this._api);
  final ApiService _api;
  Future<Result<Message,         ApiError>> sendMessage(String chatId, String content);
  Future<Result<List<Message>,   ApiError>> listMessages(String chatId, {int page = 1, int limit = 30});
}
```

Bearer-token injection is automatic via `ApiService`'s interceptor (`lib/core/services/api_service.dart:39-47`). The envelope unwraps `data` automatically (line 80-81) — services receive the `data` map directly.

---

## 7. Frontend — Providers

Reuse the existing `SocialStatus` enum from `lib/features/social/providers/user_provider.dart` (`idle / loading / success / failure`). The "use the same enum, don't invent per-feature ones" rule from `CLAUDE.md` applies.

### 7.1 `lib/features/chat/providers/chat_provider.dart` (new)

State:

```
SocialStatus listStatus, createStatus
List<Chat> chats
String? error
Set<String> busyChatIds         // currently-being-opened/created ids — tile spinners
```

Methods:

```
loadChats()                       — populates `chats`, sorted newest-first by `updatedAt`
createOrOpenChat(UserSummary)     — returns Chat on success; idempotent server-side
                                    On success: hoists the chat to the top of `chats`
                                    (or inserts if new) and returns it so the screen
                                    can `context.goNamed(chatScreen, ...)`.
upsertChatFromMessage(Message m)  — called by MessageProvider after a send.
                                    Finds the matching chat by id, replaces its
                                    lastMessage with a MessagePreview built from m,
                                    bumps it to the top, notifyListeners.
reset()                           — clears for sign-out
```

Optimistic strategy: send-message wins from `MessageProvider` push their preview into `ChatProvider` so the chat list reorders without a refetch. Cross-provider call is direct (not via Notifications) — `ChatProvider` is injected into `MessageProvider`'s constructor.

### 7.2 `lib/features/chat/providers/message_provider.dart` (new)

State (scoped to a single "current" chat at a time — this phase doesn't need a per-chat cache):

```
String? currentChatId
SocialStatus messagesStatus, sendStatus
List<Message> messages          // newest first as returned by backend; ChatScreen
                                 //  renders into a reverse:true ListView so they
                                 //  display oldest→newest from top to bottom.
int page, limit
bool hasMore                    // false once a page returns < limit
String? error
```

Methods:

```
openChat(String chatId)         — sets currentChatId, resets paging, calls loadMore()
loadMore()                      — appends next page; sets hasMore=false on short return
sendMessage(String content)     — posts; on success prepends to messages and notifies
                                    ChatProvider via the injected reference
closeChat()                     — clears currentChatId + messages (called from
                                    ChatScreen.dispose to keep memory bounded)
reset()                         — for sign-out
```

A multi-chat cache (`Map<chatId, List<Message>>`) is *not* needed in Phase 04 because the user can only view one chat at a time and Phase 05 will introduce socket-driven realtime cache anyway. Keeping `MessageProvider` single-chat scoped now keeps the design honest with current requirements (CLAUDE.md "no premature abstraction").

### 7.3 Wiring (`lib/main.dart`)

Construct in `initState`, register in `MultiProvider`, dispose in `dispose`, **and add to the sign-out reset list** in `_onAuthChanged`:

```dart
_chatService    = ChatService(_api);
_messageService = MessageService(_api);
_chatProvider   = ChatProvider(chatService: _chatService);
_messageProvider = MessageProvider(
  messageService: _messageService,
  chatProvider: _chatProvider,        // for lastMessage hoisting on send
);

// in _onAuthChanged (signout branch):
_chatProvider.reset();
_messageProvider.reset();
```

Provider order in `MultiProvider`: services first, then `ChatProvider`, then `MessageProvider` (downstream of ChatProvider).

---

## 8. Frontend — Routes + Home shell rework

### 8.1 `lib/core/constants/route_names.dart` (modify)

Add new constants and re-order the tab paths to reflect the new bottom-nav order (**Chats / Friends / Requests**):

```dart
// New
static const String chats           = 'chats';
static const String chatScreen      = 'chat_screen';
static const String chatsPath       = '/home/chats';
static const String chatScreenPath  = '/chat/:chatId';
static String chatScreenPathFor(String chatId) => '/chat/$chatId';

// Existing — kept; `search` route remains addressable from the AppBar action.
```

Keep `searchPath = '/home/search'`. The Search screen is still routed; it just no longer has a tab. The home redirect (`/home → /home/search`) **changes to `/home → /home/chats`** so post-login lands on Chats by default.

### 8.2 `lib/routes/app_router.dart` (modify)

Three changes:

1. `StatefulShellRoute.indexedStack.branches` becomes `[Chats, Friends, Requests]` in that order (Search-branch is removed from the shell).
2. The standalone Search route is kept as a top-level route under `/home/search` so the AppBar icon can `context.goNamed(RouteNames.search)` and the back-button returns to the active tab. Alternative: nest under a non-tab branch — but a top-level route is simpler and matches how `/u/:username` works today.
3. Add the chat-screen route as a top-level route (pushes over the shell — back returns to Chats tab):

```dart
GoRoute(
  path: RouteNames.chatScreenPath,
  name: RouteNames.chatScreen,
  builder: (_, state) => ChatScreen(chatId: state.pathParameters['chatId']!),
),
```

Redirect logic: the existing `_redirect` already treats anything that isn't `/login`, `/signup`, `/splash` as authenticated-only when authed. The only redirect on auth is `if (onSplash || onAuthRoute) return RouteNames.searchPath;`. **Change that to `RouteNames.chatsPath`** so post-login lands on Chats.

### 8.3 `lib/screens/home/home_shell.dart` (modify)

Tab list becomes:

```dart
static const _tabs = <_HomeTab>[
  _HomeTab(icon: Icons.chat_bubble_outline, label: 'Chats'),
  _HomeTab(icon: Icons.people_outline,      label: 'Friends'),
  _HomeTab(icon: Icons.mark_email_unread_outlined, label: 'Requests'),
];
```

AppBar gains a Search action (before the theme toggle):

```dart
IconButton(
  tooltip: 'Search users',
  icon: const Icon(Icons.search),
  onPressed: () => context.goNamed(RouteNames.search),
),
```

No other layout changes.

---

## 9. Frontend — Screens + Widgets

All screens use `AppScaffold`, `AppButton`, `AppTextField`, `AppLoader`, `AppEmptyState`, `AppErrorState`, and only `AppColors` / `AppTextStyles` / `AppSpacing` tokens. Widgets never call services — `Widget → Provider → Service → API` (spec §8 Rule 1).

### 9.1 `lib/features/chat/widgets/`

- **`chat_tile.dart`** — `ListTile`-style row: `UserAvatar(other.avatar)` + display name + last-message preview (truncated) + relative timestamp. Tapping pushes `chatScreenPath` with `chat.id`.
- **`message_bubble.dart`** — receives `Message` + `isMine` bool. Mine: right-aligned, `AppColors.primary` background. Theirs: left-aligned, surface variant. Timestamp under bubble (short form). Plain `Text(message.content)` — no rich rendering this phase.
- **`message_input.dart`** — bottom bar with `AppTextField` (multiline, max 5 lines) + send `IconButton`. Disabled when content trim is empty or `sendStatus == loading`. Pressing send calls `context.read<MessageProvider>().sendMessage(text)`.
- **`message_timestamp.dart`** *(optional helper)* — `Text` formatted via a small `relativeTime(DateTime)` util. Inline if too small to justify a file.

### 9.2 `lib/features/chat/screens/chat_list_screen.dart` (new)

`initState` → `context.read<ChatProvider>().loadChats()`. Body switches on `listStatus`:

- `loading` → `AppLoader`
- `failure` → `AppErrorState` with retry
- `success && chats.isEmpty` → `AppEmptyState`("No conversations yet", "Tap the search icon to find friends and start a chat.")
- `success && chats.isNotEmpty` → `RefreshIndicator` wrapping `ListView.separated` of `ChatTile`.

### 9.3 `lib/features/chat/screens/chat_screen.dart` (new)

Stateful, takes `chatId` from path param.

```
initState  → context.read<MessageProvider>().openChat(chatId)
dispose    → context.read<MessageProvider>().closeChat()
```

Body:

```
AppScaffold
├── AppBar: title = chat.other.displayName (read from ChatProvider by id)
├── body :
│     Expanded(
│       child: ListView.builder(
│         reverse: true,                // newest at bottom, scroll grows upward
│         itemCount: messages.length,
│         itemBuilder: (_, i) => MessageBubble(
│           message: messages[i],
│           isMine: messages[i].senderId == currentUserId,
│         ),
│         // NotificationListener<ScrollEndNotification> → if at top, loadMore()
│       ),
│     )
└── MessageInput()
```

`currentUserId` is read from `context.read<AuthProvider>().currentUser?.id`. No service call from the widget.

Empty / loading / error variants handled the same way as `ChatListScreen`.

### 9.4 Cross-feature entry points (touch-ups)

- **Friends list tile** (`lib/features/social/screens/friends_list_screen.dart`) — add a `Send message` overflow item: calls `ChatProvider.createOrOpenChat(friend)` then `context.goNamed(chatScreen, pathParameters: {'chatId': chat.id})`.
- **User profile screen** (`lib/features/social/screens/user_profile_screen.dart`) — when `relationship == friend`, render a secondary `AppButton` "Message" alongside the existing "Remove friend" button, same flow.

Both call into `ChatProvider` (not directly into `ChatService`) — feature-correct architecture (spec §8 Rule 1).

---

## 10. Cross-cutting

- **No new pub dependencies.** Timestamps formatted via a tiny inline `relativeTime` helper in `lib/features/chat/widgets/` (or extracted to `lib/core/utils/relative_time.dart` if reused elsewhere — defer that decision until a second caller appears).
- **`socket/` is still untouched.** Phase 04 adds zero socket code. The Phase 04 service shapes (`createOrGetChat`, `sendMessage`, `listMessages`) are exactly the signatures Phase 05's socket handlers will reuse — they'll fire `io.to(chatId).emit(...)` after the same DB writes.
- **`blockedUsers` / presence / `lastSeen`** remain unwritten (still reserved). The chat-creation flow does NOT check `blockedUsers` — that's part of Phase 05+ when blocking gets a real UX.
- **Spec §14 Rule 1/2** — commit per row in the delivery-order table. The plan deliberately decomposes the work into independently reviewable chunks (models, services, controllers, frontend models, frontend services, frontend providers, frontend routes, frontend screens, entry-points).
- **Linting** — every new file is `flutter_lints`-clean. The `// ignore_for_file: prefer_initializing_formals` pattern from existing providers is reused where a private underscored field is bound from a public named param.

---

## 11. Verification

End-to-end with the dev stack running (`server/npm run dev` + `flutter run -d chrome`):

1. **Backend smoke** — run the curl sequence from §4. Confirm 201/200 distinction on `create`, message 400s on length/empty, 403s on non-friend / non-participant.
2. **`flutter analyze`** — must remain lint-clean.
3. **`flutter test`** — existing `test/widget_test.dart` (splash smoke) must still pass. Optionally add a unit test for `MessageProvider.sendMessage` parsing via a mocked `ApiService`.
4. **Manual app run** with two browser profiles A and B (already friends from Phase 03):
   - A opens Chats tab (post-login default) → empty state
   - A taps search icon (AppBar) → finds B → opens profile → taps "Message"
   - Lands on `/chat/:id` for the new chat; sends "hello"
   - Chats tab now shows one chat with "hello" preview + recent timestamp
   - B opens Chats → sees chat → opens → reads "hello"
   - B replies "hi" → A's chat tile reorders to top with new preview (requires A to revisit Chats — no realtime this phase, so refresh by leaving and re-entering the tab or pull-to-refresh)
   - Second send of "hello" by A on the same chat: list still shows ONE chat (no duplicate)
   - Sign out from A → sign back in → no stale chats flash (reset() worked)
5. **Negative paths**:
   - Sending empty message → input button stays disabled; backend rejects if bypassed.
   - Sending 2001-char message → 400 surfaced as snackbar.
   - Trying to chat with a non-friend (via direct route manipulation) → 403 surfaced.

---

## Files at a glance

**New (backend):**
`server/models/chat-model.js`, `server/models/message-model.js`,
`server/services/chat-service.js`, `server/services/message-service.js`,
`server/controllers/chat-controller.js`, `server/controllers/message-controller.js`,
`server/routes/chat-routes.js`, `server/routes/message-routes.js`.

**Modified (backend):** `server/routes/index.js`.

**New (frontend):**
`lib/features/chat/models/chat.dart`, `lib/features/chat/models/message.dart`,
`lib/features/chat/services/chat_service.dart`, `lib/features/chat/services/message_service.dart`,
`lib/features/chat/providers/chat_provider.dart`, `lib/features/chat/providers/message_provider.dart`,
`lib/features/chat/screens/chat_list_screen.dart`, `lib/features/chat/screens/chat_screen.dart`,
`lib/features/chat/widgets/chat_tile.dart`, `lib/features/chat/widgets/message_bubble.dart`,
`lib/features/chat/widgets/message_input.dart`.

**Modified (frontend):**
`lib/core/constants/route_names.dart`,
`lib/routes/app_router.dart` (tab order, post-login redirect target, chat-screen route),
`lib/screens/home/home_shell.dart` (tab list + AppBar search icon),
`lib/main.dart` (services, providers, reset wiring),
`lib/features/social/screens/friends_list_screen.dart` ("Send message" overflow),
`lib/features/social/screens/user_profile_screen.dart` ("Message" button when friend).

**Removed:** none. Search screen stays — it's just no longer a tab.
