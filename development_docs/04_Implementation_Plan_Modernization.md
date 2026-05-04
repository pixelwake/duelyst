# Implementation Plan: Modernization

A phased plan for modernizing the Duelyst codebase from its 2016-era tech stack to current standards. Each phase is independent enough to be useful on its own — you don't have to complete all phases to get value.

## Design Principles

1. **Preserve the SDK.** The shared rules engine (`app/sdk/`) is the most valuable code. Modernize it, don't rewrite it.
2. **Phase by dependency depth.** Start with changes that have the smallest blast radius, build toward the deeper refactors.
3. **Keep it running.** Every phase should end with a working game. No multi-month refactors that break everything.
4. **Modern defaults.** TypeScript, native async/await, ES modules, current tooling. But pragmatic — don't gold-plate.

---

## Phase 0: Foundation (Quick Wins)

**Goal:** Modernize tooling without changing game logic. Reduce friction for development.

**Estimated effort:** 1–2 weekends

### 0.1 Replace Build System
- **Remove:** Gulp + Browserify + Babel 6
- **Replace with:** Vite (or esbuild for server-side)
- **Why:** Dramatically faster builds, HMR for client development, native ESM support, modern plugin ecosystem
- **Approach:**
  - Create `vite.config.ts` that handles CoffeeScript compilation (vite-plugin-coffeescript exists)
  - Port the asset copy tasks (rsx, localization) to Vite's static asset handling
  - Remove `gulpfile.babel.js` and `gulp/` directory
  - Update `package.json` scripts

### 0.2 Replace Kue with BullMQ
- **Remove:** Kue (unmaintained since 2017)
- **Replace with:** BullMQ (actively maintained Redis-based job queue)
- **Why:** Kue has known bugs and security issues; BullMQ has the same Redis backing with modern API
- **Scope:** `worker/worker.coffee`, `worker/jobs/`, `server/redis/r-jobs.coffee`, job creation calls in `server/game.coffee`
- **Migration:** Straightforward 1:1 — both are Redis-backed job queues

### 0.3 Update Dependencies
- Upgrade `knex` from 0.19 → current
- Upgrade `redis` client from 2.x → current (redis 4.x or ioredis)
- Replace `node-uuid` with `uuid` (modern package)
- Remove Bluebird global Promise override (use native Promise/async-await)
- Upgrade Express 4 → 5 (optional — Express 4 still works fine)

### 0.4 Development Environment
- Add `docker-compose.dev.yaml` with volume mounts and hot-reload
- Add `.nvmrc` or `volta` configuration for Node version pinning
- Create a `Makefile` or `just` file for common commands

---

## Phase 1: CoffeeScript → TypeScript Migration

**Goal:** Convert the codebase from CoffeeScript to TypeScript incrementally. Start with the SDK since it's the most valuable code.

**Estimated effort:** 3–6 weekends (incremental, can be paused)

### Strategy: Gradual Migration

CoffeeScript and TypeScript can coexist in the same project. The migration path:

1. **Use `decaffeinate`** for automated CoffeeScript → JavaScript conversion (the repo already has `bulk-decaffeinate.config.js`)
2. **Then add TypeScript types** to the converted JS files incrementally
3. **Start with leaf modules** (modifiers, actions) that have no downstream imports to break
4. **Work inward** toward `gameSession.coffee` (the most central, most complex file)

### Recommended Order

```
1. app/sdk/cards/cardType.coffee          → TypeScript enums
2. app/sdk/cards/rarityLookup.coffee      → TypeScript enums
3. app/sdk/cards/cardSetLookup.coffee     → TypeScript enums
4. app/sdk/cards/factionsLookup.coffee    → TypeScript enums
5. app/common/config.js                   → TypeScript (add const types)
6. app/sdk/modifiers/*.coffee             → TypeScript (700+ files, batch with decaffeinate)
7. app/sdk/actions/*.coffee               → TypeScript
8. app/sdk/spells/*.coffee                → TypeScript
9. app/sdk/cards/card.coffee              → TypeScript (central card class)
10. app/sdk/entities/*.coffee             → TypeScript
11. app/sdk/board.coffee                  → TypeScript
12. app/sdk/gameSession.coffee            → TypeScript (biggest file, do last)
13. app/sdk/cards/factory/**              → TypeScript (card definitions — bulk convert)
14. server/**                             → TypeScript (server code — lower priority)
```

### Type Definitions to Create Early

```typescript
// Core types that will be used everywhere
interface CardData {
  id: number;
  factionId: number;
  cardSetId: number;
  rarityId: number;
  manaCost: number;
  name: string;
}

interface EntityData extends CardData {
  atk: number;
  maxHP: number;
  speed: number;
  reach: number;
  isGeneral: boolean;
}

interface ModifierContextObject {
  type: string;
  attributeBuffs?: Record<string, number>;
  isAura?: boolean;
  auraRadius?: number;
  duration?: number;
  // ... extensible
}

interface BoardPosition {
  x: number;  // 0-8 (columns)
  y: number;  // 0-4 (rows)
}
```

---

## Phase 2: Remove Firebase Dependency

**Goal:** Replace Firebase with self-hosted alternatives. This is the deepest refactor and the biggest unlock for independent deployment.

**Estimated effort:** 4–8 weekends

### 2.1 Replace Firebase Auth

**Current:** `FIREBASE_LEGACY_TOKEN` used as JWT secret across REST middleware, Socket.IO auth.

**Replace with:** Standard JWT with a self-managed secret.

**Scope:**
- `server/middleware/signed_in.coffee` — change JWT verification to use local secret
- `server/routes/session.coffee` — change token issuance to use local secret
- `server/game.coffee` + `server/single_player.coffee` — update Socket.IO JWT auth
- **Configuration:** Add `JWT_SECRET` to config, remove `FIREBASE_LEGACY_TOKEN`

**Approach:** This is relatively straightforward — the auth scheme is already JWT-based, it just uses Firebase's token as the shared secret. Replace the secret and update the verification calls.

### 2.2 Replace Firebase Realtime Database (Data Sync)

**Current:** `server/lib/data_access/sync.coffee` and related modules push/pull user state to Firebase RTDB paths.

**Replace with:** Postgres (for persistent data) + Redis Pub/Sub or SSE (for realtime updates).

**Scope (large):**
- `server/lib/duelyst_firebase_module.coffee` — remove entirely
- `server/lib/firebase_promises.coffee` — remove entirely
- `server/lib/data_access/sync.coffee` — rewrite to use Postgres directly
- `server/lib/data_access/*.coffee` — audit all modules for Firebase calls
- `worker/jobs/*.coffee` — remove Firebase sync from job handlers
- `server/routes/api/me/spectate.coffee` — replace Firebase reads
- `server/middleware/is_friend.coffee` — replace Firebase buddy/block reads

**Data paths to migrate:**
- `user-inventory` → Postgres `user_card_collection`
- `user-decks` → Postgres `user_decks`
- `user-quests` → Postgres (new table or existing)
- `user-ranking` → Postgres rank tables
- Matchmaking errors → Redis
- Game steps → Redis (already partially there via `GameManager`)

### 2.3 Replace Firebase Step Sync

**Current:** Game steps (action bundles) are serialized through Firebase (`deserializeStepFromFirebase` naming throughout SDK).

**Replace with:** Direct Socket.IO events (the Socket.IO connection already exists).

**Scope:**
- `server/game.coffee` — change step publishing to emit directly to connected clients
- `app/sdk/gameSession.coffee` — rename/update deserialization methods
- Client `NetworkManager` — update to receive steps via Socket.IO instead of Firebase

### 2.4 Remove Build-Time Firebase Coupling

- Remove `validateFirebase` task from Gulp/Vite build
- Make `FIREBASE_URL` optional in config
- Client should get server configuration at runtime, not build time

### 2.5 Clean Up

- Remove `firebase`, `firebase-admin`, `backfire` from dependencies
- Remove `firebaseRules.json` (no longer needed)
- Update all documentation
- Remove Firebase-specific test files

---

## Phase 3: Replace Client Rendering

**Goal:** Replace the legacy Cocos2d-JS + Backbone/Marionette client with a modern web framework.

**Estimated effort:** Significant — this is essentially a new client. 8–16 weekends minimum.

### Engine Options

| Engine | Type | Pros | Cons |
|--------|------|------|------|
| **Phaser 4** | Full game framework | Built-in physics, scene management, input, audio. TypeScript-first. Active development (RC7 as of March 2026). ~1.2MB bundle. | Larger bundle, opinionated structure |
| **PixiJS v8** | Rendering library | Lightweight (~450KB), fastest pure rendering, maximum control. Unified package. | Need to build game systems yourself (scene, input, audio) |
| **Excalibur** | TypeScript game engine | Purpose-built for TypeScript, clean API, good docs. 2,255 stars. | Smaller community than Phaser/Pixi |
| **PlayCanvas** | Full engine | 3D capable, editor available, ECS architecture. | Heavier than needed for 2D card game |

**Recommendation:** **Phaser 4** for fastest path to a working game, or **PixiJS v8** for maximum control and smallest bundle. Given that Duelyst is fundamentally a 2D sprite-based game with UI overlays, Phaser 4's built-in systems would save significant development time.

### Client Architecture

```
src/
├── engine/           # Phaser/PixiJS game instance, scene management
├── sdk/              # Migrated game rules engine (from Phase 1)
├── scenes/
│   ├── boot/         # Asset loading
│   ├── menu/         # Main menu, deck builder
│   ├── game/         # In-match game board
│   └── collection/   # Card collection, crafting
├── ui/               # React or Svelte for menus/overlays (optional)
├── network/          # Socket.IO client, state sync
├── audio/            # Audio engine wrapper
├── assets/           # Sprite sheets, audio files (from app/resources)
└── types/            # Shared TypeScript definitions
```

### Rendering Approach

The existing Cocos2d-JS rendering maps to modern equivalents:

| Duelyst Current | Modern Equivalent |
|-----------------|-------------------|
| Cocos2d-JS sprites | Phaser Sprites / PixiJS Sprites |
| `.plist` + `.png` sprite sheets | TexturePacker → Phaser atlas / PixiJS spritesheet |
| Cocos2d-JS actions (move, fade, scale) | Phaser tweens / PixiJS gsap |
| GLSL shaders | Phaser/PixiJS shader filters |
| Cocos2d-JS particle system | Phaser particles / PixiJS particle-emitter |

### UI Layer

For menus, deck builder, collection screen — consider a hybrid approach:
- **Game board:** Phaser/PixiJS canvas rendering
- **UI overlays:** React or Svelte components overlaid on the canvas (common pattern in modern web games)
- **Communication:** Shared state store (Zustand, Svelte stores) connecting UI framework to game engine

---

## Phase 4: Modern Deployment

**Goal:** Make the game deployable to the public internet with modern infrastructure.

### 4.1 Containerization Improvements
- Multi-stage Docker builds for smaller images
- Health checks on all services
- Proper signal handling for graceful shutdown

### 4.2 Database
- Postgres managed service (Neon, Supabase, or cloud provider)
- Redis managed service (Upstash, Railway, or cloud provider)
- Database migration CI (run migrations in deploy pipeline)

### 4.3 Client Hosting
- Static site deployment (Vercel, Netlify, Cloudflare Pages)
- CDN for game assets
- Client-server separation (client at `game.yourdomain.com`, API at `api.yourdomain.com`)

### 4.4 Game Servers
- Container orchestration (Fly.io, Railway, or K8s)
- Auto-scaling based on active games
- WebSocket sticky sessions for Socket.IO

### 4.5 Monitoring
- Structured logging (Pino or Winston 3)
- Error tracking (Sentry)
- Game metrics (active players, queue times, game lengths)

---

## Phase Dependency Map

```
Phase 0 (Foundation) ──────────────────────────────────┐
    │                                                    │
    ├── Phase 1 (CoffeeScript → TypeScript) ────────────┤
    │       │                                            │
    │       └── Phase 3 (New Client) ───────────────────┤
    │                                                    │
    ├── Phase 2 (Remove Firebase) ──────────────────────┤
    │                                                    │
    └───────────────────────────────────────── Phase 4 (Deploy)
```

- **Phase 0** is prerequisite for everything — do this first
- **Phase 1 and Phase 2** can be done in parallel (different parts of the codebase)
- **Phase 3** benefits from Phase 1 (TypeScript SDK to build against) but can start in parallel
- **Phase 4** benefits from Phase 2 (no Firebase = simpler deployment) but can start with Phase 0

## Estimated Total Timeline

| Phase | Effort | Can Start After |
|-------|--------|----------------|
| Phase 0 | 1–2 weekends | Immediately |
| Phase 1 | 3–6 weekends (incremental) | Phase 0 |
| Phase 2 | 4–8 weekends | Phase 0 |
| Phase 3 | 8–16 weekends | Phase 0 (better after Phase 1) |
| Phase 4 | 2–4 weekends | Phase 0 (better after Phase 2) |

**Total:** ~18–36 weekends of focused work for a full modernization. But each phase delivers value independently — you don't need to do everything.

## Recommended Starting Path

1. **Phase 0** — Get modern tooling in place
2. **Phase 1 (partial)** — Convert the SDK enums and config to TypeScript
3. **Phase 2.1** — Replace Firebase auth (smallest scope, biggest unlock)
4. **Phase 1 (continue)** — Keep converting SDK modules to TypeScript
5. **Phase 2.2–2.5** — Remove remaining Firebase dependency
6. **Phase 3** — New client (when you're ready for the big build)
7. **Phase 4** — Deploy when you want others to play
