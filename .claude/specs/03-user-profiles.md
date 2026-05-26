# Letters — Phase 03 Specification

## User Discovery & Friend System

---

# 1. Phase Overview

## Objective

Phase 03 introduces the social layer of Letters.

This phase allows users to:

* discover other users
* send friend requests
* accept or decline requests
* manage friends
* prepare relationships for future chat systems

This is the first phase where relational user data becomes important.

The architecture in this phase must remain:

* modular
* scalable
* reusable
* optimized for future realtime systems

---

# 2. Phase Goals

## Primary Goals

Implement:

* username search
* friend request system
* friends list system
* relationship validation
* protected social APIs

---

## Secondary Goals

Prepare infrastructure for:

* chat permissions
* online presence
* chat creation
* user relationship caching

---

## Non-Goals

The following should NOT be implemented in this phase:

* realtime sockets
* messaging
* group systems
* media uploads
* notifications
* voice/video systems

---

# 3. User Relationship System

# Relationship Types

A user can have:

```text
friends
sentRequests
receivedRequests
blockedUsers (future-ready)
```

---

# Relationship Rules

## Rule 1

Users cannot send requests to themselves.

---

## Rule 2

Users cannot send duplicate requests.

---

## Rule 3

Users cannot send requests to existing friends.

---

## Rule 4

Accepting a request:

* removes pending request
* adds both users to friends lists

---

## Rule 5

Declining a request:

* removes request only

---

# 4. Database Design

# 4.1 Updated User Schema

```json
{
  "_id": "ObjectId",

  "username": "ameen",

  "displayName": "Ameen",

  "password": "hashed_password",

  "avatar": "",

  "bio": "",

  "friends": [
    "ObjectId"
  ],

  "sentRequests": [
    "ObjectId"
  ],

  "receivedRequests": [
    "ObjectId"
  ],

  "blockedUsers": [
    "ObjectId"
  ],

  "isOnline": false,

  "lastSeen": "Date",

  "createdAt": "Date",

  "updatedAt": "Date"
}
```

---

# 4.2 Schema Rules

## friends

Contains:

* accepted friend relationships

---

## sentRequests

Contains:

* pending outgoing requests

---

## receivedRequests

Contains:

* pending incoming requests

---

## blockedUsers

Reserved for future functionality.

Do NOT fully implement blocking yet.

---

# 4.3 Database Requirements

## Required Indexes

```javascript
username: unique index
```

---

## Required Schema Features

Use:

```javascript
timestamps: true
```

---

# 5. Backend Architecture

# 5.1 Required Routes

```text
GET    /api/users/search
GET    /api/users/profile/:username

POST   /api/friends/send-request
POST   /api/friends/accept-request
POST   /api/friends/decline-request
POST   /api/friends/remove-friend

GET    /api/friends/list
GET    /api/friends/requests
```

---

# 5.2 Folder Structure

```text
server/
│
├── controllers/
│   ├── user-controller.js
│   └── friend-controller.js
│
├── services/
│   ├── user-service.js
│   └── friend-service.js
│
├── routes/
│   ├── user-routes.js
│   └── friend-routes.js
```

---

# 5.3 Controller Responsibilities

## user-controller.js

Handles:

* user search
* profile retrieval

Must NOT contain:

* database business logic

---

## friend-controller.js

Handles:

* friend request endpoints
* response formatting

Must NOT contain:

* relationship logic

---

# 5.4 Service Responsibilities

## user-service.js

Handles:

* user searching
* user retrieval
* query optimization

---

## friend-service.js

Handles:

* send request logic
* accept request logic
* decline request logic
* remove friend logic
* relationship validation

---

# 6. Frontend Architecture

# 6.1 New Feature Structure

```text
lib/
│
├── features/
│   └── social/
│       ├── models/
│       ├── providers/
│       ├── screens/
│       ├── services/
│       └── widgets/
```

---

# 6.2 Required Screens

## Search Users Screen

Features:

* search by username
* live search
* profile preview
* send request button

---

## Friend Requests Screen

Features:

* incoming requests
* accept button
* decline button

---

## Friends List Screen

Features:

* list all friends
* friend profile preview
* remove friend option

---

## User Profile Screen

Features:

* avatar
* username
* display name
* friendship status

---

# 6.3 Required Providers

```text
social_provider.dart
user_provider.dart
friend_provider.dart
```

---

# 6.4 Provider Responsibilities

## user_provider.dart

Handles:

* user searching
* profile retrieval

---

## friend_provider.dart

Handles:

* friend requests
* friend list
* relationship state

---

## social_provider.dart

Handles:

* shared social state
* future scalability

---

# 7. Frontend Rules

# Rule 1

Widgets must NEVER directly call APIs.

Correct flow:

```text
Widget
→ Provider
→ Service
→ API
```

---

# Rule 2

Providers must NOT contain UI logic.

Avoid:

```dart
Navigator.push()
showDialog()
ScaffoldMessenger.of(context)
```

inside providers.

---

# Rule 3

Keep providers modular.

Avoid:

```text
MegaProvider managing everything
```

---

# 8. API Standards

# Success Response

```json
{
  "success": true,
  "message": "Friend request sent",
  "data": {}
}
```

---

# Error Response

```json
{
  "success": false,
  "message": "User already added"
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
* 409 Conflict
* 500 Internal Server Error

---

# 9. Search System

# Username Search Requirements

## Search Behavior

Search should:

* be case-insensitive
* support partial matches
* exclude current user

---

# Pagination

Search results should support:

```text
limit
page
```

even if UI pagination is added later.

---

# Performance Rules

Avoid:

```text
loading entire user collection
```

Use:

* indexed queries
* limited result sets

---

# 10. Security Rules

# Rule 1

All social routes must require authentication.

---

# Rule 2

Users cannot manipulate:

* other user relationships
* unauthorized requests

---

# Rule 3

Validate all ObjectIds before queries.

---

# Rule 4

Never expose:

* passwords
* tokens
* sensitive internal data

---

# 11. Error Handling

# Frontend Must Handle

* empty search results
* duplicate requests
* network failures
* loading states
* unauthorized states

---

# Backend Must Handle

* invalid IDs
* duplicate relationships
* invalid requests
* missing users
* unauthorized access

---

# 12. Deliverables

By the end of Phase 03:

## Users Can

* search users
* send friend requests
* accept requests
* decline requests
* remove friends
* view friends list

---

## Backend Deliverables

* social APIs
* relationship validation
* optimized queries
* modular services

---

## Frontend Deliverables

* social screens
* provider integration
* friend state management
* profile previews

---

# 13. Claude Code Development Rules

Claude Code MUST follow these rules:

## Rule 1

Generate features module-by-module.

---

## Rule 2

Do NOT generate all social systems in one response.

---

## Rule 3

Separate:

* controllers
* services
* providers
* widgets

strictly.

---

## Rule 4

Avoid duplicated relationship logic.

---

## Rule 5

Prioritize scalable architecture over shortcuts.

---

# 14. Suggested Development Order

# Step 1

Update User schema

---

# Step 2

Build backend relationship logic

---

# Step 3

Build social APIs

---

# Step 4

Test APIs manually

Use:

* Postman
  or
* Insomnia

---

# Step 5

Build frontend providers

---

# Step 6

Build social screens

---

# Step 7

Integrate APIs into frontend

---

# 15. Success Criteria

Phase 03 is complete when:

* users can discover each other
* friend requests work correctly
* duplicate requests are prevented
* friendships persist correctly
* APIs remain modular
* frontend architecture remains clean
* future chat systems can build on top of relationships

---

# 16. Final Notes

Phase 03 establishes the social graph of Letters.

This phase is critical because:

* chats depend on relationships
* online systems depend on user connections
* future scalability depends on clean relationship architecture

A poorly designed relationship system becomes extremely difficult to maintain later.

Keep the system:

* modular
* validated
* reusable
* scalable
