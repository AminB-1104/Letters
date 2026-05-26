# Letters — Phase 01 Specification Document

**Initial Setup & Foundation Architecture**

## 1. Project Description

### Overview

Letters is a cross-platform real-time messaging platform designed to allow users to communicate instantly through private conversations using unique usernames.

The application is being built with a strong focus on:

- scalability
- clean architecture
- realtime communication
- maintainability
- modern UI/UX

Letters will support:

- Android
- iOS
- Web
- Desktop (future support)

The platform will eventually include:

- realtime private messaging
- friend system
- online presence
- typing indicators
- media sharing
- group chats
- voice/video communication

However, Phase 01 focuses ONLY on building the foundational architecture required for long-term scalable development.

### Vision

The long-term goal of Letters is to create a polished modern messaging platform with production-level architecture while avoiding spaghetti code from the beginning.

The project should:

- remain modular
- scale cleanly
- support future features without major rewrites
- maintain separation of concerns
- encourage reusable systems

### Phase 01 Scope

Phase 01 ONLY covers:

- frontend architecture setup
- backend architecture setup
- environment configuration
- reusable infrastructure
- coding standards
- development workflow

Phase 01 does NOT include:

- messaging features
- socket communication
- friend systems
- media uploads
- push notifications
- advanced UI systems

## 2. Phase Objective

The purpose of Phase 01 is to establish a stable and scalable foundation for all future development.

This phase is considered the most important phase of the entire project because all future systems will depend on the architecture decisions made here.

Primary objectives:

- prevent spaghetti code
- enforce modular architecture
- establish reusable systems
- prepare for realtime infrastructure
- standardize development patterns

## 3. Technology Stack

### Frontend — Flutter

Purpose:

- cross-platform UI development

Required packages (already chosen — do not substitute):

- `provider` — state management (chosen over Riverpod for this project; do not suggest switching)
- `go_router` — routing
- `dio` — HTTP client
- `shared_preferences` — local key/value storage
- `flutter_dotenv` — env/secrets loading

### Backend — Node.js + Express

Purpose:

- REST API server
- authentication infrastructure
- future realtime infrastructure

Recommended packages:

- `express`
- `mongoose`
- `dotenv`
- `cors`
- `jsonwebtoken`
- `bcrypt`
- `nodemon`

> The backend lives in a sibling directory/repo (`server/`), not inside the Flutter project. Phase 01 only scaffolds it — no business endpoints yet.

### Database — MongoDB

Purpose:

- persistent application storage

## 4. Frontend Architecture Specification

### 4.1 Required Folder Structure

```
lib/
│
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   ├── services/
│   └── widgets/
│
├── models/
│
├── providers/
│
├── routes/
│
├── screens/
│
├── features/
│
└── main.dart
```

### 4.2 Architecture Rules

#### Rule 1 — No API Calls Inside Widgets

Widgets must NEVER directly communicate with APIs.

Correct flow:

```
Widget -> Provider -> Service -> API
```

Incorrect flow:

```
Widget -> API directly
```

#### Rule 2 — Reusable UI Components

All shared UI elements must be reusable.

Examples:

- buttons
- input fields
- loaders
- dialogs
- app bars

Reusable widgets must be placed inside:

```
core/widgets/
```

#### Rule 3 — Centralized Theme System

All colors, typography, spacing, and styles must be centralized.

Required location:

```
core/theme/
```

Avoid:

- hardcoded colors
- duplicated styling

#### Rule 4 — Centralized Navigation

Routing must be centralized using `go_router`.

All routes should be defined inside:

```
routes/
```

### 4.3 State Management

State management is **provider** (locked decision — see §3). Do not introduce Riverpod, Bloc, or alternatives.

Application state should be separated into:

- auth state
- user state
- chat state
- app settings

Avoid:

- giant global providers
- mixed responsibilities

### 4.4 API Service Layer

A reusable API service wrapper must be created on top of `dio`.

Responsibilities:

- base URL handling
- token handling
- request interceptors
- response interceptors
- error handling

The UI should NEVER directly handle raw HTTP requests.

### 4.5 Environment Loading

`flutter_dotenv` must be wired before `runApp`:

- create `.env` at the project root
- add `.env` to `.gitignore`
- declare `.env` under `flutter > assets` in `pubspec.yaml`
- call `await dotenv.load()` from `main()` before `runApp(...)`

## 5. Backend Architecture Specification

### 5.1 Required Folder Structure

```
server/
│
├── config/
│
├── controllers/
│
├── middleware/
│
├── models/
│
├── routes/
│
├── services/
│
├── socket/
│
├── utils/
│
└── server.js
```

### 5.2 Backend Layer Responsibilities

#### `controllers/`

Contains:

- request handling logic

Must NOT contain:

- database schemas
- reusable business logic
- server configuration

#### `models/`

Contains:

- database schemas
- model definitions

#### `routes/`

Contains:

- endpoint definitions

#### `middleware/`

Contains:

- auth middleware
- validation middleware
- global error handling

#### `services/`

Contains:

- reusable business logic

Examples:

- auth services
- token services
- hashing services

#### `socket/`

Reserved for future realtime systems. Do NOT implement socket functionality during Phase 01.

### 5.3 Environment Variables

Required `.env` variables:

```
PORT=
MONGO_URI=
JWT_SECRET=
```

Rules:

- never hardcode secrets
- never commit `.env`
- always use environment configuration

### 5.4 API Standards

#### Success Response Format

```json
{
  "success": true,
  "message": "Operation successful",
  "data": {}
}
```

#### Error Response Format

```json
{
  "success": false,
  "message": "Error message"
}
```

#### HTTP Status Standards

Required status codes:

- `200 OK`
- `201 Created`
- `400 Bad Request`
- `401 Unauthorized`
- `404 Not Found`
- `500 Internal Server Error`

## 6. Database Setup

### 6.1 Database Connection Requirements

Requirements:

- centralized MongoDB connection
- connection error handling
- automatic reconnection support

### 6.2 Initial Collections

Phase 01 should ONLY create:

- `Users` collection

Do NOT create:

- chats
- messages
- notifications

until later phases.

## 7. Authentication Preparation

Authentication should only be **structurally prepared** in this phase — scaffolding exists, but no end-to-end flow is wired.

Prepare:

- JWT utility functions (`sign`, `verify`) — exported, unused
- password hashing utilities (bcrypt wrappers) — exported, unused
- auth middleware structure — defined and importable, but not attached to any protected route

Do NOT:

- implement `/login` or `/register` endpoints
- persist or issue tokens to clients
- attach auth middleware to any route

## 8. Error Handling System

### Frontend Error Handling

The frontend must support:

- loading states
- API error states
- empty states
- retry systems

### Backend Error Handling

The backend must include:

- centralized error middleware
- async error wrappers
- standardized error responses

## 9. Coding Standards

### Naming Conventions

- `camelCase` — variables and functions (both stacks)
- `PascalCase` — widgets and classes (both stacks)
- `snake_case` — **Dart filenames** (required by Dart analyzer; e.g. `auth_service.dart`)
- `kebab-case` — **Node.js filenames** (e.g. `auth-service.js`)

### File Responsibility Rules

Each file must have ONE responsibility only.

Avoid:

- massive controller files
- massive service files
- mixed frontend/backend logic

### Function Rules

Functions should:

- remain small
- remain reusable
- avoid deep nesting

## 10. Git Workflow

### Recommended Branch Structure

- `main`
- `develop`
- `feature/*`

### Commit Naming Convention

Examples:

- `feat: setup app routing`
- `feat: create mongodb connection`
- `fix: api interceptor issue`
- `refactor: separate auth service`

## 11. Deliverables

By the end of Phase 01:

### Frontend Deliverables

- working Flutter project
- centralized routing (`go_router`)
- theme system
- reusable widget structure
- `provider`-based state management setup
- `flutter_dotenv` wired in `main()`

### Backend Deliverables

- working Express server
- MongoDB connection
- middleware system
- utility system
- environment configuration

### Development Deliverables

- clean architecture
- modular structure
- reusable systems
- documented workflow
- zero spaghetti code

## 12. Claude Code Development Rules

Claude Code must follow these rules strictly:

1. Never generate the entire application at once.
2. Generate systems module-by-module.
3. Maintain strict folder separation.
4. Avoid duplicate logic.
5. Prefer reusable architecture over quick fixes.
6. Always separate:
   - UI
   - business logic
   - API logic
   - database logic

## 13. Success Criteria

Phase 01 is considered complete when:

- frontend runs successfully
- backend runs successfully
- MongoDB connects successfully
- folder structure is finalized
- routing system works
- architecture rules are established
- future phases can be added cleanly

## 14. Final Notes

Phase 01 determines the long-term quality of the entire Letters project.

A strong foundation prevents:

- spaghetti code
- scaling issues
- duplicated logic
- maintenance problems

The quality of future development depends entirely on how well this phase is implemented.
