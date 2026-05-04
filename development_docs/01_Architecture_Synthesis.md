# Architecture Synthesis

A comprehensive technical analysis of the OpenDuelyst codebase — what's here, how it works, and what matters for future development.

## Tech Stack Overview

| Layer | Technology | Status (2026) |
|-------|-----------|---------------|
| **Game logic** | CoffeeScript (shared SDK) | Functional but dated; ~39% of codebase |
| **Client UI shell** | Backbone.js 1.x + Marionette 2.x | Legacy; no longer maintained upstream |
| **Game renderer** | Cocos2d-JS ~3.3 (vendored) | Legacy; last major release was 2015-era |
| **Server runtime** | Node.js (targets Node 24) | Current |
| **API framework** | Express 4 | Stable but old patterns |
| **Realtime** | Socket.IO 4 | Current |
| **Database** | PostgreSQL 13 (via Knex ORM) | Solid; Knex version is old (0.19) |
| **Cache/queues** | Redis 6 + Kue | Redis fine; Kue is unmaintained |
| **Auth/sync** | Firebase Realtime DB + Legacy Token | Deepest pain point — see Firebase section |
| **Build system** | Gulp 4 + Browserify + Babel 6 | Legacy; should be Vite/esbuild |
| **Package management** | Yarn Berry 4.x | Modern |
| **Infrastructure** | Docker Compose | Good |
| **IaC** | Terraform | Present but optional |
| **CI** | GitHub Actions | Functional |

## Codebase Structure

```
duelyst/
├── app/                    # CLIENT — browser application
│   ├── sdk/                # SHARED RULES ENGINE (runs on client AND server)
│   │   ├── gameSession.coffee      # Core: board state, turns, action pipeline
│   │   ├── cards/                  # Card definitions, factories, lookups
│   │   │   ├── card.coffee         # Base card class
│   │   │   ├── cardType.coffee     # Type enum (Unit, Spell, Artifact, Tile)
│   │   │   ├── factionsLookup.coffee   # Faction IDs
│   │   │   ├── factionFactory.coffee   # Faction metadata, generals, starter decks
│   │   │   ├── cardSetLookup.coffee    # Expansion set IDs
│   │   │   ├── rarityLookup.coffee     # Rarity tiers
│   │   │   └── factory/            # Per-set card definitions
│   │   │       ├── core/           # Base set (largest)
│   │   │       ├── shimzar/        # Denizens of Shimzar expansion
│   │   │       ├── bloodstorm/     # Rise of the Bloodborn
│   │   │       ├── unity/          # Unearthed Prophecy
│   │   │       ├── firstwatch/     # Immortal Vanguard
│   │   │       ├── wartech/        # Trials of Mythron
│   │   │       ├── coreshatter/    # Fate's Design (final set)
│   │   │       ├── monthly/        # Monthly card releases
│   │   │       └── misc/           # Tutorial, bosses, tiles, gauntlet specials
│   │   ├── modifiers/              # 700+ modifier files — the mechanics engine
│   │   ├── actions/                # Atomic state mutations (play, attack, move, etc.)
│   │   ├── spells/                 # Spell targeting and effect logic
│   │   ├── artifacts/              # Artifact equip/durability logic
│   │   ├── entities/               # Entity, Unit, Tile base classes
│   │   ├── agents/                 # SDK-side AI helpers
│   │   └── board.coffee            # Board state and spatial queries
│   ├── common/                 # Shared config, utilities, session helpers
│   │   └── config.js           # Game constants (board size, mana, speeds, etc.)
│   ├── view/                   # Cocos2d-JS game view layer
│   ├── ui/                     # Backbone/Marionette UI components
│   ├── vendor/                 # Vendored Cocos2d-JS and other libraries
│   ├── data/                   # Asset manifests (resources.js, fx.js)
│   ├── audio/                  # Audio engine, music, SFX wrappers
│   ├── shaders/                # GLSL shaders for visual effects
│   ├── localization/           # i18next setup + locale JSON files
│   │   └── locales/
│   │       ├── en/             # English (primary)
│   │       ├── de/             # German
│   │       └── zh-tw/          # Chinese Traditional
│   ├── resources/              # Game assets (sprites, audio, UI, maps, particles)
│   └── original_resources/     # Source artwork (higher-res, organized by feature)
│
├── server/                 # BACKEND — Node.js services
│   ├── api.coffee          # Express HTTP server (port 3000)
│   ├── game.coffee         # Socket.IO multiplayer server (port 8001)
│   ├── single_player.coffee # Socket.IO AI server (port 8000)
│   ├── express.coffee      # Express app configuration
│   ├── routes/             # REST API endpoints
│   │   ├── api.coffee      # Route registration
│   │   ├── session.coffee  # Auth/session management
│   │   ├── matchmaker.coffee # Matchmaking endpoints
│   │   └── api/me/         # User-specific endpoints (inventory, decks, etc.)
│   ├── lib/                # Server libraries
│   │   ├── data_access/    # Database operations (heavy Firebase coupling)
│   │   ├── duelyst_firebase_module.coffee  # Firebase admin wrapper
│   │   └── firebase_promises.coffee        # Firebase RTDB promise helpers
│   ├── middleware/          # Auth middleware (signed_in, is_friend)
│   ├── redis/               # Redis managers
│   │   ├── r-gamemanager.coffee    # Game session storage
│   │   ├── r-tokenmanager.coffee   # Matchmaking tokens
│   │   └── r-playerqueue.coffee    # Matchmaking queue
│   ├── migrations/          # 86 Knex migration files (Postgres schema)
│   ├── ai/                  # Server-side AI opponent logic
│   │   ├── starter_ai.js    # Simple AI for starter decks
│   │   ├── phase_ii_ai.js   # Advanced strategic AI
│   │   ├── scoring/         # AI evaluation (position, bounty, threshold)
│   │   ├── decks/           # Pre-built AI decks
│   │   └── card_intent/     # Card-specific AI knowledge
│   └── validators/          # Anti-cheat action validators
│
├── worker/                 # BACKGROUND JOBS (Kue consumer)
│   ├── worker.coffee       # Job processor entry
│   └── jobs/               # Job definitions (matchmaking, achievements, etc.)
│
├── config/                 # Convict configuration
│   ├── config.js           # Schema + env mapping
│   ├── development.json    # Dev defaults
│   ├── staging.json        # Staging overrides
│   └── production.json     # Production overrides
│
├── docker/                 # Dockerfiles for each service
├── bin/                    # Service entry points
├── gulp/                   # Build pipeline modules
├── packages/               # Vendored workspace packages (chroma-js, warlock, etc.)
├── desktop/                # Desktop app build (separate workspace)
├── test/                   # Mocha tests (unit, integration, perf)
├── terraform/              # Optional cloud IaC
├── scripts/                # Operational scripts
└── docs/                   # QUICKSTART, ARCHITECTURE, CONTRIBUTING
```

## Key Architectural Patterns

### 1. Shared Rules Engine (The Best Pattern Here)

The game rules engine at `app/sdk/` runs identically on both client and server. This is the single most important architectural decision in the codebase.

- **Server imports the SDK directly:** `SDK = require '../app/sdk.coffee'` in `server/game.coffee`
- **Authoritative execution:** Server calls `action.resetForAuthoritativeExecution()` before `gameSession.executeAction(action)` — the server replays every move through the same rules, never trusting client state
- **Scrubbed replication:** `UtilsGameSession.scrubGameSessionData` strips hidden information (opponent hand, deck) before sending state to each player

This pattern means there's one implementation of every card, ability, and interaction. No client-server desync bugs from duplicated logic.

### 2. Action/Event-Sourcing Pipeline

Gameplay progresses through explicit, serializable actions:

```
Player Input → Action Created → Validators Gate → GameSession.executeAction()
    → Step Created → Event Bus Fires → Modifiers React → Followup Actions
        → State Updated → Step Serialized → Network Sync via Firebase
```

**Core classes:**
- **`GameSession`** (`app/sdk/gameSession.coffee`) — owns board, players, turns, event bus, action queue
- **`Action`** subclasses (`app/sdk/actions/`) — `PlayCardFromHandAction`, `AttackAction`, `MoveAction`, `EndTurnAction`, `DieAction`, `ResignAction`, etc.
- **`Step`** — network-serialized bundle of signed actions; the unit of sync between client and server
- **Validators** — gate actions for anti-cheat; server-side validators reject invalid moves

### 3. Modifier Composition (The Mechanics Engine)

Cards don't have hardcoded abilities. Instead, they compose behaviors from **modifiers** — over 700 modifier classes in `app/sdk/modifiers/`. This is a component-based design:

- **Base `Modifier`** — event hooks, attribute buffs (rebase/normal/aura), duration, durability, aura radius/filters
- **Keywords** are modifiers: Provoke = aura applying `ModifierProvoked` to adjacent enemies. Flying = speed buff to `SPEED_INFINITE`. Rush = refresh exhaustion on summon.
- **Cards attach modifiers at creation:** `card.setInherentModifiersContextObjects([ModifierProvoke.createContextObject()])`
- **Modifiers react to events:** Opening Gambit fires on `PlayCardAction`. Dying Wish fires on `DieAction`. Deathwatch fires when any unit dies.

This is extensible — adding a new keyword means writing a new modifier class and attaching it to cards.

### 4. Firebase as Deep Dependency (The Biggest Pain Point)

Firebase is not a thin layer. It's woven through auth, data sync, realtime communication, and even the build system:

**Auth:** `FIREBASE_LEGACY_TOKEN` is the JWT secret for REST API middleware (`server/middleware/signed_in.coffee`), session routes, and Socket.IO auth on both game servers. Removing Firebase means replacing the entire auth scheme.

**Data sync:** `server/lib/data_access/sync.coffee` and much of `data_access/*` push/pull user state to Firebase RTDB paths (inventory, decks, quests, ranking, matchmaking errors). Worker jobs also sync to Firebase.

**Realtime:** Game steps flow through Firebase (the `deserializeStepFromFirebase` naming is throughout the SDK).

**Build-time:** `gulpfile.babel.js` validates `FIREBASE_URL` exists before building. The client expects Firebase at runtime.

**Scope to remove:** Replace auth (JWT with own keys), migrate all RTDB trees to Postgres/Redis, rewrite sync + worker jobs, update step serialization naming, update build/env/docs, reimplement Firebase security rules logic.

## Service Topology (Docker Compose)

```
                    ┌─────────────────┐
                    │   Browser Client │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌────────────┐ ┌────────────┐ ┌────────────┐
     │ API Server │ │Game Server │ │  SP Server  │
     │  :3000     │ │  :8001     │ │  :8000      │
     │ (Express)  │ │(Socket.IO) │ │(Socket.IO)  │
     └─────┬──────┘ └─────┬──────┘ └──────┬──────┘
           │               │               │
     ┌─────┼───────────────┼───────────────┼──────┐
     │     ▼               ▼               ▼      │
     │  ┌──────┐      ┌──────┐      ┌──────────┐ │
     │  │Postgres│     │Redis │      │ Firebase │ │
     │  │  :5432 │     │:6379 │      │  (RTDB)  │ │
     │  └────────┘     └──────┘      └──────────┘ │
     │                     ▲                       │
     │              ┌──────┴──────┐                │
     │              │   Worker    │                │
     │              │ (Kue jobs)  │                │
     │              └─────────────┘                │
     └─────────────────────────────────────────────┘
```

## Database Schema Highlights

86 Knex migrations define the Postgres schema. Key tables:

| Table | Purpose |
|-------|---------|
| `users` | Credentials, rank, wallet (gold/spirit), quest state, payment fields |
| `games` | Game records — players, factions, winner, status, game data JSON |
| `user_decks` | Deck definitions — faction, card list (integer array), metadata |
| `user_games` | Per-user game history — rewards, rank deltas, opponent info |
| `user_card_collection` | Owned cards per user |
| `user_progression` | Daily/faction progression tracking |
| Various | Gauntlet runs, spirit orbs, cosmetics, rifts, shop, challenges, replays, achievements |

## Build Pipeline

The Gulp-based build produces a browser-ready bundle:

1. **`validateFirebase`** — ensures `FIREBASE_URL` is set
2. **`vendor`** — bundles Cocos2d-JS from `app/vendor/`
3. **`css`** — compiles SCSS
4. **`html`** — processes Handlebars templates
5. **`localization:copy`** — copies locale JSON
6. **`rsx:packages`** — processes asset manifests
7. **`js`** — Browserify bundles `app/` CoffeeScript/JS through Babel
8. **`rsx:copy` / `rsx:copy:web`** — copies game resources to `dist/`

Output goes to `dist/src/` and is served by the API server or uploaded to CDN.

## Test Infrastructure

- **Framework:** Mocha with spec reporter
- **Unit tests:** `test/unit/sdk/` (card rules, game session), `test/unit/session/`, `test/unit/firebase/`
- **Integration tests:** `test/integration/data_access/` (users, decks, sync), `test/integration/firebase/`
- **REST tests:** `test/rest/` (API endpoints, matchmaker)
- **Perf tests:** `test/perf/sdk/`
- **Dependencies:** Unit tests run standalone; integration tests require Postgres, Redis, and Firebase (via Docker Compose test services)

## Configuration

Convict schema in `config/config.js` with env-specific JSON overrides. Key configuration:

- **Ports:** API (3000), Game (8001), SP (8000), Worker UI (4000)
- **Firebase:** URL, legacy token, project ID, client email, private key
- **Postgres:** Connection string via `POSTGRES_CONNECTION`
- **Redis:** Host, port, TTL for game sessions
- **Feature flags:** Invite codes, recaptcha, matchmaking, Consul discovery
- **CDN/S3:** Optional asset hosting configuration

## Known Technical Debt

1. **CoffeeScript everywhere** — 39.4% of codebase; no longer a mainstream choice
2. **Kue** — unmaintained job queue library
3. **Firebase legacy token** — deprecated authentication pattern
4. **Gulp + Browserify** — should be Vite/esbuild for modern DX
5. **Old dependency versions** — Knex 0.19, Express 4, redis 2.x, `node-uuid`
6. **Bluebird** as global Promise override in all bins
7. **Backbone/Marionette** UI — no longer maintained upstream
8. **Cocos2d-JS** vendored at ~3.3 — no modern development
9. **Build-time Firebase coupling** — can't build without a Firebase URL
10. **Extensive TODO/FIXME markers** throughout server code
