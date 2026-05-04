# Implementation Plan: Running Duelyst As-Is

Step-by-step guide to getting the existing game running locally, plus troubleshooting for known issues.

## Prerequisites

| Requirement | Details |
|-------------|---------|
| **Node.js** | Version 24 (use [Volta](https://volta.sh/) or nvm to manage versions) |
| **Yarn** | Berry (v4+) — installed via `corepack enable && corepack prepare yarn@stable --activate` |
| **Docker** | Docker Desktop or Docker Engine + Docker Compose |
| **Firebase account** | Free Google Firebase account (Realtime Database) |
| **OS** | Linux, macOS, or Windows (WSL recommended on Windows) |

## Phase 1: Firebase Setup

This is the most involved prerequisite. Firebase is deeply coupled to the auth and realtime systems.

### Step 1.1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project (name doesn't matter — e.g., "duelyst-local")
3. **Important:** When choosing database location, select **US Central** — the legacy Firebase client in the codebase has known incompatibility with EU and Asia-Pacific database URLs ([Issue #192](https://github.com/open-duelyst/duelyst/issues/192))

### Step 1.2: Create Realtime Database

1. In Firebase Console → Build → Realtime Database
2. Create database in **locked mode** (you'll set rules manually)
3. Note the database URL (format: `https://your-project-id-default-rtdb.firebaseio.com/`)

### Step 1.3: Set Security Rules

1. In the Realtime Database → Rules tab
2. Copy the contents of `firebaseRules.json` from the repo root into the rules editor
3. Publish the rules

### Step 1.4: Generate Legacy Token

The game uses Firebase's legacy authentication system. You need a **database secret**:

1. Firebase Console → Project Settings (gear icon) → Service Accounts
2. Look for "Database secrets" section
3. Click "Show" or generate a new secret
4. Copy the secret — this becomes `FIREBASE_LEGACY_TOKEN`

**Note:** Firebase has deprecated database secrets. If the option isn't visible, you may need to use the Firebase CLI or REST API to generate one. Check the [QUICKSTART.md](../docs/QUICKSTART.md) for current guidance.

### Step 1.5: Generate Service Account Key

1. Firebase Console → Project Settings → Service Accounts
2. Click "Generate new private key"
3. Save the downloaded JSON file as `serviceAccountKey.json` in the repo root
4. **Do NOT commit this file** (it's in `.gitignore`)

### Step 1.6: Create .env File

Create a `.env` file in the repo root:

```bash
FIREBASE_URL=https://your-project-id-default-rtdb.firebaseio.com/
FIREBASE_LEGACY_TOKEN=your_database_secret_here
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n"
```

The `CLIENT_EMAIL` and `PRIVATE_KEY` values come from the `serviceAccountKey.json` file.

## Phase 2: Build the Client

### Step 2.1: Install Dependencies

```bash
# Enable Yarn Berry via corepack
corepack enable
corepack prepare yarn@stable --activate

# Install dependencies (focused install — skips optional workspace deps)
yarn workspaces focus

# Build the TypeScript chroma-js package
yarn tsc:chroma-js
```

### Step 2.2: Build the Game

```bash
# Set FIREBASE_URL and build (Gulp pipeline)
FIREBASE_URL=https://your-project-id-default-rtdb.firebaseio.com/ yarn build
```

This runs the full Gulp build pipeline: clean → vendor bundle → CSS → HTML → localization → asset packaging → JS bundle → resource copy.

**Expected output:** Build artifacts in `dist/src/`.

**Build time:** Several minutes on first run (Browserify bundling is slow).

## Phase 3: Start Services

### Step 3.1: Run Database Migration

```bash
# Start Postgres and run migrations
docker compose up migrate
```

This starts the `db` (Postgres) service and runs all 86 Knex migrations to create the schema. Wait for it to complete, then it will exit.

### Step 3.2: Start All Services

```bash
docker compose up
```

This starts:
- **redis** — Redis 6 on port 6379
- **db** — Postgres 13 (already running from migrate step)
- **api** — Express API server on port 3000 (serves the client)
- **game** — Multiplayer game server on port 8001
- **sp** — Single-player/AI server on port 8000
- **worker** — Background job processor

### Step 3.3: Verify

Look for the log line:
```
Duelyst 'development' started on port 3000
```

Open **http://localhost:3000** in a browser.

## Phase 4: Play

1. **Register** — Create an account at the registration screen. All accounts are local.
2. **All content unlocked** — Playing locally automatically unlocks all factions, cards, and provides bonus Gold and Spirit for deck building.
3. **Single-player** — Play against AI opponents using pre-built decks.
4. **Multiplayer** — Two browser windows on localhost can play against each other via the matchmaker.

## Known Issues & Troubleshooting

### Firebase Region Error
**Symptom:** Client can't connect or errors on startup.
**Cause:** Firebase database is not in US Central region.
**Fix:** Create a new Firebase project with a US Central database. The legacy Firebase client doesn't support newer regional URLs. ([Issue #192](https://github.com/open-duelyst/duelyst/issues/192))

### Build Fails Without FIREBASE_URL
**Symptom:** Gulp build crashes at `validateFirebase`.
**Fix:** Ensure `FIREBASE_URL` is set as an environment variable and ends with `firebaseio.com/` (trailing slash matters).

### Offline Development Not Supported
**Symptom:** Can't run without internet/Firebase.
**Cause:** Firebase is required for auth, step sync, and data operations. The Firebase emulator is not supported due to legacy client version. ([Issue #278](https://github.com/open-duelyst/duelyst/issues/278))
**Workaround:** None currently. Firebase connection is mandatory.

### Mobile/Small Viewport Issues
**Symptom:** Map or hero GIFs break on small screens.
**Cause:** Known rendering issues at small viewport sizes. ([Issue #290](https://github.com/open-duelyst/duelyst/issues/290))
**Fix:** Use desktop browser or larger screen.

### Docker Memory
**Symptom:** Services crash or don't start.
**Fix:** Ensure Docker has at least 4GB RAM allocated. Postgres + Redis + 4 Node services can be memory-heavy.

### Node Version
**Symptom:** Build or runtime errors.
**Fix:** Use Node 24 exactly. The project uses CoffeeScript compilation and Babel 6 presets that may break on other versions. Use Volta or nvm.

## Optional: Desktop Build

The `desktop/` workspace can build standalone desktop applications:

```bash
cd desktop
yarn install
yarn build:linux   # or build:mac, build:windows
```

Pre-built desktop packages (~600MB each) are available on the [upstream releases page](https://github.com/open-duelyst/duelyst/releases).

## Quick Reference

| Service | URL / Port | Purpose |
|---------|-----------|---------|
| Client | http://localhost:3000 | Game in browser |
| API | :3000 | REST API + client serving |
| Game Server | :8001 | Multiplayer Socket.IO |
| SP Server | :8000 | Single-player/AI Socket.IO |
| Worker UI | :4000 | Kue job dashboard (disabled by default) |
| Postgres | :5432 | User/game data |
| Redis | :6379 | Sessions, queues, matchmaking |

## npm/yarn Scripts Reference

| Script | Purpose |
|--------|---------|
| `yarn build` | Full client build (Gulp) |
| `yarn build:app` | JS-only build |
| `yarn build:web` | Static assets only |
| `yarn api` | Run API server directly (outside Docker) |
| `yarn game` | Run game server directly |
| `yarn sp` | Run single-player server directly |
| `yarn worker` | Run worker directly |
| `yarn migrate:latest` | Run Postgres migrations |
| `yarn migrate:rollback` | Roll back last migration |
| `yarn test:unit` | Run unit tests |
| `yarn test:integration` | Run integration tests (needs running services) |
| `yarn watch` | Gulp watch for development |
