# Letters — Phase 04 Specification

## Chat System Foundation

---

# 1. Phase Overview

## Objective

Phase 04 introduces the core messaging architecture of Letters.

This phase establishes:

* conversation systems
* message storage
* chat relationships
* message retrieval
* scalable messaging database structure

This phase focuses ONLY on the messaging foundation.

Realtime communication using sockets will be implemented later in Phase 05.

---

# 2. Phase Goals

## Primary Goals

Implement:

* private chat creation
* persistent message storage
* conversation retrieval
* message history retrieval
* recent chat list system

---

## Secondary Goals

Prepare architecture for:

* realtime sockets
* typing indicators
* online presence
* message delivery status
* media messaging

---

## Non-Goals

The following should NOT be implemented in this phase:

* realtime sockets
* typing indicators
* message seen status
* push notifications
* media uploads
* group chats
* voice/video systems

---

# 3. Messaging Architecture

# Core System Design

The messaging system MUST use:

* separate Chats collection
* separate Messages collection

Messages must NEVER be stored directly inside:

```text id="q0j4u8"
User documents
```

---

# Architecture Flow

```text id="v1u7p2"
User
→ Chat
→ Messages
```

---

# Relationship Structure

## One Chat

Contains:

* two participants
* latest message reference

---

## One Message

Belongs to:

* one chat
* one sender

---

# 4. Database Design

# 4.1 Chats Collection

```json id="gnhlmb"
{
  "_id": "ObjectId",

  "participants": [
    "ObjectId"
  ],

  "lastMessage": "ObjectId",

  "createdAt": "Date",

  "updatedAt": "Date"
}
```

---

# 4.2 Messages Collection

```json id="z6rqlg"
{
  "_id": "ObjectId",

  "chatId": "ObjectId",

  "sender": "ObjectId",

  "content": "Hello",

  "type": "text",

  "createdAt": "Date"
}
```

---

# 4.3 Chat Rules

## participants

Must contain:

* exactly two users

for private chats.

---

## lastMessage

Should store:

* latest message reference

for optimized chat list loading.

---

# 4.4 Message Rules

## type

Currently supports:

```text id="4s5v0l"
text
```

Future-ready for:

```text id="zjlwmf"
image
voice
file
```

---

# 4.5 Database Requirements

## Required Features

Use:

```javascript id="4w5iq8"
timestamps: true
```

---

## Required Indexes

Recommended indexes:

```javascript id="fq2j04"
chatId
participants
createdAt
```

---

# 5. Backend Architecture

# 5.1 Required Routes

```text id="qarfkz"
POST   /api/chats/create
GET    /api/chats/list
GET    /api/chats/:chatId

POST   /api/messages/send
GET    /api/messages/:chatId
```

---

# 5.2 Folder Structure

```text id="4zwr2v"
server/
│
├── controllers/
│   ├── chat-controller.js
│   └── message-controller.js
│
├── services/
│   ├── chat-service.js
│   └── message-service.js
│
├── routes/
│   ├── chat-routes.js
│   └── message-routes.js
│
├── models/
│   ├── chat-model.js
│   └── message-model.js
```

---

# 5.3 Controller Responsibilities

## chat-controller.js

Handles:

* chat creation requests
* chat retrieval requests
* response formatting

Must NOT contain:

* business logic
* database relationship logic

---

## message-controller.js

Handles:

* message requests
* pagination requests
* response formatting

Must NOT contain:

* database business logic

---

# 5.4 Service Responsibilities

## chat-service.js

Handles:

* create chat
* validate participants
* fetch chat list
* prevent duplicate chats

---

## message-service.js

Handles:

* send messages
* retrieve messages
* pagination logic
* update last message

---

# 6. Chat System Rules

# Rule 1 — Prevent Duplicate Chats

Only ONE private chat may exist between two users.

Before creating a new chat:

* check existing conversations first

---

# Rule 2 — Friendship Validation

Users may ONLY create chats with:

```text id="cv5u7v"
existing friends
```

---

# Rule 3 — Message Ownership

Only participants inside a chat may:

* send messages
* retrieve messages

---

# Rule 4 — Empty Messages

Prevent:

```text id="lv0rqq"
empty messages
```

---

# Rule 5 — Message Length Limit

Recommended:

```text id="rdyijy"
max 2000 characters
```

---

# 7. Frontend Architecture

# 7.1 New Feature Structure

```text id="l6a1so"
lib/
│
├── features/
│   └── chat/
│       ├── models/
│       ├── providers/
│       ├── screens/
│       ├── services/
│       └── widgets/
```

---

# 7.2 Required Screens

## Chat List Screen

Features:

* recent chats
* latest message preview
* timestamps
* open conversation

---

## Chat Screen

Features:

* message list
* send message input
* message timestamps

---

# 7.3 Required Providers

```text id="fh7ngt"
chat_provider.dart
message_provider.dart
```

---

# 7.4 Provider Responsibilities

## chat_provider.dart

Handles:

* chat list
* current chat state
* chat creation

---

## message_provider.dart

Handles:

* message retrieval
* send message state
* pagination state

---

# 8. Frontend Rules

# Rule 1

Widgets must NEVER directly call APIs.

Correct architecture:

```text id="kg1jlwm"
Widget
→ Provider
→ Service
→ API
```

---

# Rule 2

Providers must NOT contain UI logic.

Avoid:

```dart id="n42jxt"
Navigator.push()
showDialog()
ScaffoldMessenger.of(context)
```

inside providers.

---

# Rule 3

Message rendering widgets should remain reusable.

Examples:

* message bubble
* chat tile
* message input
* timestamp widget

---

# 9. Message Pagination

# Pagination Requirements

Messages MUST support:

```text id="x6sjah"
limit
page
```

---

# Loading Direction

Messages should load:

```text id="l8z1pp"
newest → oldest
```

---

# Performance Rules

Avoid:

```text id="r7yqes"
loading entire chat history at once
```

---

# 10. API Standards

# Success Response

```json id="qfuzvn"
{
  "success": true,
  "message": "Message sent",
  "data": {}
}
```

---

# Error Response

```json id="7qpcqb"
{
  "success": false,
  "message": "Unauthorized access"
}
```

---

# Required Status Codes

Use:

* 200 OK
* 201 Created
* 400 Bad Request
* 401 Unauthorized
* 403 Forbidden
* 404 Not Found
* 500 Internal Server Error

---

# 11. Security Rules

# Rule 1

All chat routes require authentication.

---

# Rule 2

Users cannot access chats they are not participants in.

---

# Rule 3

Validate all ObjectIds before queries.

---

# Rule 4

Sanitize message content before storage.

---

# 12. Error Handling

# Frontend Must Handle

* empty chat lists
* failed messages
* loading states
* unauthorized access
* pagination loading

---

# Backend Must Handle

* invalid chat IDs
* unauthorized users
* duplicate chats
* invalid messages
* missing users

---

# 13. Deliverables

By the end of Phase 04:

## Users Can

* create private chats
* send text messages
* retrieve message history
* view recent conversations

---

## Backend Deliverables

* chat APIs
* message APIs
* scalable database structure
* pagination support
* modular messaging services

---

## Frontend Deliverables

* chat list UI
* chat screen UI
* provider integration
* message rendering system

---

# 14. Claude Code Development Rules

Claude Code MUST follow these rules:

## Rule 1

Generate messaging modules separately.

---

## Rule 2

Do NOT generate entire messaging system in one response.

---

## Rule 3

Maintain strict separation between:

* chats
* messages
* providers
* services
* controllers

---

## Rule 4

Avoid duplicate relationship logic.

---

## Rule 5

Prioritize scalable database design over shortcuts.

---

# 15. Suggested Development Order

# Step 1

Create Chat model

---

# Step 2

Create Message model

---

# Step 3

Build chat services

---

# Step 4

Build message services

---

# Step 5

Build messaging APIs

---

# Step 6

Test APIs manually

Use:

* Postman
  or
* Insomnia

---

# Step 7

Build frontend providers

---

# Step 8

Build chat UI screens

---

# Step 9

Integrate APIs into frontend

---

# 16. Success Criteria

Phase 04 is complete when:

* chats can be created
* messages persist correctly
* chat history loads correctly
* duplicate chats are prevented
* pagination works
* users cannot access unauthorized chats
* architecture remains modular
* realtime systems can be added cleanly later

---

# 17. Final Notes

Phase 04 builds the core messaging engine of Letters.

This phase is one of the most important architectural phases because:

* realtime systems depend on it
* database scalability depends on it
* future performance depends on it

A clean messaging foundation prevents:

* slow chat performance
* difficult socket integration
* massive database problems later

Keep the messaging architecture:

* modular
* scalable
* optimized
* reusable
