# Letters — Phase 02 Specification

## Authentication System

---

# 1. Phase Overview

## Objective

Phase 02 focuses on implementing the complete authentication system for Letters.

This phase establishes:

* user identity
* secure authentication
* persistent login sessions
* protected backend routes
* frontend authentication flow

Authentication is the foundation for all future features including:

* friend system
* realtime messaging
* online presence
* user profiles

---

# 2. Phase Goals

## Primary Goals

* Allow users to create accounts
* Allow users to log in securely
* Implement JWT authentication
* Persist user sessions
* Protect backend APIs

---

## Non-Goals

The following should NOT be implemented in this phase:

* realtime sockets
* messaging
* friend system
* media uploads
* push notifications
* group chats

---

# 3. Authentication Flow

# Registration Flow

```text
User enters details
→ frontend validation
→ backend validation
→ password hashing
→ user creation
→ JWT token generation
→ token returned
→ session stored locally
```

---

# Login Flow

```text
User enters credentials
→ backend verifies credentials
→ JWT generated
→ token returned
→ token stored locally
→ user authenticated
```

---

# Persistent Login Flow

```text
App launches
→ check local token
→ validate token
→ fetch current user
→ auto-login user
```

---

# 4. Frontend Architecture

# 4.1 New Screens

## Splash Screen

Responsibilities:

* check authentication status
* validate saved token
* redirect user

---

## Login Screen

Features:

* username field
* password field
* validation states
* loading states
* error handling

---

## Register Screen

Features:

* username field
* display name field
* password field
* confirm password field
* validation states

---

# 4.2 Frontend Folder Additions

```text
lib/
│
├── features/
│   └── auth/
│       ├── models/
│       ├── providers/
│       ├── screens/
│       ├── services/
│       └── widgets/
```

---

# 4.3 State Management

State management will use Provider.

Responsibilities:

* manage authentication state
* manage loading state
* manage current user state
* manage token persistence

---

# 4.4 Provider Structure

```text
lib/
│
├── providers/
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── chat_provider.dart
│   └── socket_provider.dart
```

---

# 4.5 Provider Rules

## Rule 1 — Providers Must Not Contain UI Logic

Avoid:

```dart
showDialog()
ScaffoldMessenger.of(context)
Navigator.push()
```

inside providers.

Providers should ONLY manage:

* state
* business logic
* API communication

---

## Rule 2 — Keep Providers Small

Avoid:

```text
MegaProvider handling entire application
```

Instead:

* separate providers by feature
* separate responsibilities clearly

---

## Rule 3 — Widgets Listen to Providers

Correct architecture:

```text
Widget
→ Provider
→ Service
→ API
```

---

# 4.6 Local Storage

Use:

```text
shared_preferences
```

Purpose:

* store JWT token
* persist login sessions

---

# 5. Backend Architecture

# 5.1 Auth Routes

Required routes:

```text
POST /api/auth/register
POST /api/auth/login
GET /api/auth/me
```

---

# 5.2 Folder Responsibilities

## controllers/auth-controller.js

Responsibilities:

* request handling
* response formatting

Must NOT contain:

* hashing logic
* JWT generation logic

---

## services/auth-service.js

Responsibilities:

* authentication business logic
* password hashing
* token generation
* credential validation

---

## middleware/auth-middleware.js

Responsibilities:

* JWT verification
* protected route access

---

# 6. Database Design

# Users Collection

```json
{
  "_id": "ObjectId",
  "username": "ameen",
  "displayName": "Ameen",
  "password": "hashed_password",
  "createdAt": "Date"
}
```

---

# Validation Rules

## Username

Requirements:

* unique
* lowercase only
* minimum 3 characters
* maximum 20 characters

---

## Password

Requirements:

* minimum 6 characters

---

## Display Name

Requirements:

* minimum 2 characters
* maximum 30 characters

---

# 7. Security Standards

# Password Security

Passwords MUST:

* be hashed using bcrypt
* never be stored raw
* never be returned in API responses

---

# JWT Authentication

Use:

* JWT access tokens

Protected routes require:

```text
Authorization: Bearer TOKEN
```

---

# Environment Variables

Required:

```env
JWT_SECRET=
JWT_EXPIRES_IN=
```

---

# 8. API Standards

# Success Response

```json
{
  "success": true,
  "message": "Login successful",
  "data": {}
}
```

---

# Error Response

```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

---

# Required Status Codes

Use:

* 200 OK
* 201 Created
* 400 Bad Request
* 401 Unauthorized
* 409 Conflict
* 500 Internal Server Error

---

# 9. Frontend Rules

## Rule 1

Widgets must NEVER directly call APIs.

Correct flow:

```text
Widget → Provider → Service → API
```

---

## Rule 2

Authentication state must remain centralized.

---

## Rule 3

Do not store user passwords locally.

---

## Rule 4

Token handling must happen inside services/providers.

---

# 10. Backend Rules

## Rule 1

Controllers must remain thin.

---

## Rule 2

Business logic belongs inside services.

---

## Rule 3

Do not duplicate validation logic.

---

## Rule 4

Never expose sensitive data in responses.

---

# 11. Error Handling

# Frontend

Must handle:

* invalid credentials
* expired tokens
* network failures
* loading states

---

# Backend

Must include:

* centralized error handling
* async wrappers
* validation errors

---

# 12. Deliverables

By the end of Phase 02:

## Frontend Deliverables

* splash screen
* login screen
* register screen
* persistent auth state
* protected navigation

---

## Backend Deliverables

* auth APIs
* JWT system
* password hashing
* auth middleware
* protected routes

---

## User Deliverables

Users can:

* register
* login
* stay logged in
* logout securely

---

# 13. Claude Code Development Rules

Claude Code must follow these rules:

## Rule 1

Generate authentication modules separately.

---

## Rule 2

Never generate the entire auth system in one response.

---

## Rule 3

Maintain strict folder separation.

---

## Rule 4

Avoid duplicate auth logic.

---

## Rule 5

Separate:

* controllers
* services
* middleware
* models

---

# 14. Success Criteria

Phase 02 is complete when:

* users can register
* users can login
* JWT authentication works
* sessions persist after app restart
* protected routes work
* invalid tokens are rejected
* authentication architecture remains modular

---

# 15. Final Notes

Authentication is the foundation of the entire Letters platform.

Every future feature depends on:

* authenticated users
* secure sessions
* stable auth architecture

A clean authentication system prevents:

* security issues
* duplicated logic
* difficult future integrations
* unstable user sessions
