# Game Design Document — Duelyst

A reverse-engineered game design document based on code analysis of the OpenDuelyst repository. This captures the complete mechanical foundation of the game as it existed at shutdown.

## Game Overview

**Duelyst** is a 1v1 tactical card game played on a 9x5 grid. Players build decks around a faction and its General (hero), then deploy units, cast spells, and equip artifacts to destroy the opponent's General. The game blends collectible card game deckbuilding with turn-based tactical positioning.

**Core loop:** Draw cards → spend mana to play cards → position units on the grid → attack with units → end turn.

**Win condition:** Reduce the opponent's General to 0 HP. If both Generals die simultaneously, the game is a draw. Players can also concede (Resign action).

---

## The Board

**Grid:** 9 columns × 5 rows (defined in `app/common/config.js` as `BOARDCOL = 9`, `BOARDROW = 5`).

**Spawn rules:** Units can be placed on unoccupied tiles adjacent to friendly units (using `CONFIG.SPAWN_PATTERN_STEP`), or on the tile your General occupies if unobstructed. The Airdrop keyword bypasses this — Airdrop units can be placed on any unoccupied tile.

**Movement:** Base movement speed is 2 tiles (`CONFIG.SPEED_BASE = 2`). Movement is non-diagonal in practice (pathfinding around obstructing entities). The Flying keyword grants effectively unlimited movement (`CONFIG.SPEED_INFINITE = BOARDCOL + BOARDROW`).

**Attack range:** Melee range is 1 tile (`CONFIG.REACH_MELEE = 1`). Ranged units can attack across the full board (`CONFIG.REACH_RANGED = BOARDCOL + BOARDROW`).

**Board center:** Derived from dimensions; relevant for some card effects and positioning AI.

---

## Factions

Six playable factions, each with a distinct mechanical identity, plus Neutral cards usable by all factions.

| ID | Faction | Dev Name | Description |
|----|---------|----------|-------------|
| 1 | **Lyonar Kingdoms** | `lyonar` | Holy warriors, healing, divine bond, provoke-heavy |
| 2 | **Songhai Empire** | `songhai` | Backstab, teleportation, spell damage, combo-oriented |
| 3 | **Vetruvian Imperium** | `vetruvian` | Dervish tokens, obelysk structures, blast effects |
| 4 | **Abyssian Host** | `abyssian` | Swarm, deathwatch, shadow creep, sacrifice mechanics |
| 5 | **Magmar Aspects** | `magmar` | Big stats, grow, rebirth (eggs), natural selection |
| 6 | **Vanar Kindred** | `vanar` | Infiltrate, walls, stun, board control, positioning |
| 100 | **Neutral** | `neutral` | Faction-agnostic cards usable by all decks |

**Non-playable:** Tutorial (200, disabled), Boss (300, disabled — used for PvE boss encounters).

### Generals

Each faction has **three Generals** (Primary, Secondary, Tertiary) tracked via `generalIdsByOrder` in `factionFactory.coffee`. Each General has:
- A unique **signature card** (Bloodbound Spell / BBS) — a repeating spell on a cooldown timer
- Portrait, concept art, announcer SFX
- Faction-specific taunt callouts and responses (keyed by opponent faction/general)

### Starter Decks

Each faction defines a `starterDeck` — a list of card IDs that new players receive. These are defined in `factionFactory.coffee`.

---

## Card Types

Defined in `app/sdk/cards/cardType.coffee`:

| Type | ID | Description |
|------|----|-------------|
| **Unit** | 3 | Minions deployed to the board with ATK, HP, movement. Starts exhausted (can't act on the turn summoned unless they have Rush). All units have inherent Strikeback (counter-attack). |
| **Spell** | 4 | One-time effects — damage, buffs, removal, positioning, draw, etc. Applied via targeting patterns (single target, area, board-wide). |
| **Artifact** | 6 | Equipment attached to the General. Applies hidden, non-dispellable modifiers with durability. Maximum 3 artifacts equipped (`CONFIG.MAX_ARTIFACTS`); oldest is destroyed if cap exceeded. |
| **Tile** | 5 | Board-persistent effects (e.g., Shadow Creep, Hallowed Ground). Not targetable by default, not obstructing. Dispel/Silence kills tiles. |

### Card Properties (Base Class)

From `app/sdk/cards/card.coffee`:
- `manaCost` — resource cost to play
- `rarityId` — collectibility tier
- `factionId` — faction allegiance
- `raceId` — tribal tag (for Bond, synergy)
- `cardSetId` — which expansion set
- `modifiersContextObjects` — array of modifier definitions (the card's abilities)
- Presentation: portrait, animation resource, FX resource, sound resource

### Unit-Specific Properties

From `app/sdk/entities/entity.coffee` and `app/sdk/entities/unit.coffee`:
- `atk` — attack damage
- `maxHP` — maximum health
- `damage` — current damage taken (effective HP = maxHP - damage)
- `speed` — movement range per turn (default 2)
- `reach` — attack range (default 1 = melee)
- `isGeneral` — whether this is the player's hero
- `signatureCardData` — for Generals, reference to their BBS spell

---

## Rarity System

From `app/sdk/cards/rarityLookup.coffee`:

| Rarity | ID | Collectible? |
|--------|----|-------------|
| **Fixed** | 0 | No — basic cards |
| **Common** | 1 | Yes |
| **Rare** | 2 | Yes |
| **Epic** | 3 | Yes |
| **Legendary** | 4 | Yes |
| **TokenUnit** | 5 | No — summoned tokens |
| **Mythron** | 6 | Yes — special trial cards (Wartech set) |

Collectibility is determined by rarity: Common, Rare, Epic, Legendary, and Mythron cards appear in the collection and can be crafted/disenchanted. Fixed and TokenUnit cards are not collectible.

---

## Mana / Resource System

**Starting mana:** Player 1 starts with **2 mana**. Player 2 starts with **3 mana** (1 extra to compensate for going second).

**Mana growth:** At the start of each turn (after the first), the active player's maximum mana increases by 1, up to a cap of **9** (`CONFIG.MAX_MANA = 9`). Remaining mana is then fully refreshed.

**Mana tiles:** The board features collectible mana tiles that grant bonus mana when a unit moves onto them (handled via `PlayerModifierManaModifier` with `bonusMana`).

**Non-active player:** Retains their current remaining mana (clamped to their maximum), enabling some strategic mana banking between turns.

---

## Modifier System (Keywords & Abilities)

The modifier system is the mechanical heart of Duelyst. Over **700 modifier classes** live in `app/sdk/modifiers/`, registered via `modifierFactory.coffee`.

### Core Modifier Architecture

From `app/sdk/modifiers/modifier.coffee`:
- **Attribute buffs** — three tiers: rebase (set base value), normal (additive), aura (temporary while source exists)
- **Event hooks** — modifiers react to game events (action before/after, turn start/end, damage, death, etc.)
- **Auras** — radius-based effects that apply/remove sub-modifiers to entities within range
- **Duration** — turn-limited effects (start of turn, end of turn)
- **Durability** — charge-based effects (e.g., artifacts lose durability on General damage)
- **Stacking** — modifiers can stack or be unique
- **Keywords** — `isKeyworded: true` marks modifiers that show as named keywords in the UI

### Keyword Reference

| Keyword | File | Mechanical Implementation |
|---------|------|--------------------------|
| **Provoke** | `modifierProvoke.coffee` | Aura (radius 1, enemies only) → applies `ModifierProvoked`, forcing adjacent enemies to attack this unit |
| **Ranged** | `modifierRanged.coffee` | Reach buff: `CONFIG.REACH_RANGED - CONFIG.REACH_MELEE` = full board attack range |
| **Flying** | `modifierFlying.coffee` | Speed buff: `CONFIG.SPEED_INFINITE` = can move anywhere on the board |
| **Rush** | `modifierFirstBlood.coffee` | On activate: refreshes exhaustion if summoned this turn (can attack immediately) |
| **Airdrop** | `modifierAirdrop.coffee` | Deployment override: valid target positions = all unobstructed tiles (bypass adjacency rule) |
| **Blast** | `modifierBlastAttack.coffee` | Custom attack pattern: `CONFIG.PATTERN_BLAST` — hits all enemies in cardinal line through target |
| **Frenzy** | `modifierFrenzy.coffee` | After melee attack: chains additional attacks to all other adjacent enemies |
| **Opening Gambit** | `modifierOpeningGambit.coffee` | Fires once when card is played from hand (not summoned by other effects) |
| **Dying Wish** | `modifierDyingWish.coffee` | Fires when this unit dies (`DieAction` on self) |
| **Deathwatch** | `modifierDeathWatch.coffee` | Fires when any other unit dies (not self). Many subclasses for specific effects |
| **Backstab** | `modifierBackstab.coffee` | On attack: if target is behind attacker (positional check), bonus damage + disable strikeback |
| **Infiltrate** | `modifierInfiltrate.coffee` | Conditional buff active when unit is on enemy half of board (x-position check based on player) |
| **Grow** | `modifierGrow.coffee` | Start-of-turn buff: +ATK/+HP each of your turns. Variant: `ModifierGrowOnBothTurns` |
| **Rebirth** | `modifierRebirth.coffee` | On death: spawns an Egg entity with `ModifierEgg`; egg hatches into original unit next turn |
| **Bond** | `modifierBond.coffee` | On summon: if another friendly unit shares the same `raceId` (tribe), trigger a one-time effect |
| **Strikeback** | (inherent on all units) | Counter-attack when attacked in melee. Backstab explicitly disables this. |

### Additional Modifier Patterns (from filenames)

- **SummonWatch** — trigger when any unit is summoned
- **StartTurnWatch / EndTurnWatch** — trigger at turn boundaries
- **TakeDamageWatch / HealWatch** — trigger on damage/healing events
- **Synergize** — trigger when a spell is cast
- **Stun** — prevents action for a duration
- **Wall** — structure-type units (can't move, often have special properties)
- **Token** — summoned unit markers
- **Dispel/Silence** — removes all removable modifiers from a target

---

## Card Sets (Expansions)

From `app/sdk/cards/cardSetLookup.coffee` and the factory directory:

| ID | Set Name | Dev Name | Factory Dir | Approx. Cards |
|----|----------|----------|-------------|---------------|
| 1 | **Core Set** | `core` | `factory/core/` | 300+ (largest set — ~40-50 per faction + 100+ neutral) |
| 2 | **Denizens of Shimzar** | `shimzar` | `factory/shimzar/` | ~100 |
| 3 | **Rise of the Bloodborn** | `bloodstorm` | `factory/bloodstorm/` | ~40 (smaller mini-expansion) |
| 4 | **Unearthed Prophecy** | `unity` | `factory/unity/` | ~40 |
| 5 | **Immortal Vanguard** | `firstwatch` | `factory/firstwatch/` | ~100 |
| 6 | **Trials of Mythron** | `wartech` | `factory/wartech/` | ~100 |
| 7 | **Combined Unlockables** | `combinedunlockables` | (shared) | Collection unlock set |
| 8 | **Fate's Design** | `coreshatter` | `factory/coreshatter/` | ~100 (final expansion) |

Additionally: **Monthly cards** (`factory/monthly/`) released in themed batches (movement, replace, etc.), and **Miscellaneous** cards for tutorial, bosses, tiles, and gauntlet specials.

---

## Game Flow

### Match Setup
1. Players are matched (or play vs AI)
2. Each player has a deck (max 40 cards, max 3 copies of any card) with a General
3. Both players draw opening hands
4. Generals are placed on opposite sides of the board
5. Player 1 starts with 2 mana; Player 2 starts with 3 mana

### Turn Structure
1. **Start of turn:** Maximum mana increases by 1 (if not first turn); remaining mana refreshes to maximum; exhaustion refreshed on all your units
2. **Main phase:** Player can (in any order):
   - Move units (each unit can move once per turn)
   - Attack with units (each unit can attack once per turn)
   - Play cards from hand (costs mana)
   - Use General's signature card (BBS) if available
3. **End of turn:** `EndTurnAction` triggers end-of-turn effects; turn passes to opponent

### Signature Cards (BBS)
Each General has a unique signature spell that becomes available on a timer. The system tracks activation readiness via `_getNumberOfTurnsUntilPlayerActivatesSignatureCard` in `gameSession.coffee`. The signature card doesn't cost a card from your hand — it's an extra resource.

### Game End
- A General dying triggers `gameSession.p_requestGameOver()`
- `_validateGameOverRequest` checks for modifier interventions (e.g., effects that prevent death or swap generals)
- If one General is dead: opponent wins
- If both Generals dead: draw
- Concede: `ResignAction` (extends `DieAction`) sets `player.hasResigned = true`

---

## Deck Building Rules

From `app/common/config.js`:
- **Deck size:** 40 cards maximum (`CONFIG.MAX_DECK_SIZE = 40`)
- **Card copies:** Maximum 3 of any card (`CONFIG.MAX_DECK_DUPLICATES = 3`)
- **Gauntlet deck size:** 31 cards (`CONFIG.MAX_DECK_SIZE_GAUNTLET = 31`)
- **One General per deck** (determines faction)
- **Cards must match faction or be Neutral**

---

## AI System

Two tiers of AI opponent, implemented server-side:

### Starter AI (`server/ai/starter_ai.js`)
- Simpler decision-making for new players
- Difficulty levels 0–1
- Uses pre-built decks from `server/ai/decks/`

### Phase II AI (`server/ai/phase_ii_ai.js`)
- More sophisticated strategic opponent
- Uses a **scoring framework** under `server/ai/scoring/`:
  - **Base scoring** — fundamental value assessment
  - **Position scoring** — tactical positioning evaluation (specific files for Provoke, Frenzy, Backstab positioning)
  - **Phase scoring** — game-phase-dependent strategy
  - **Bounty** — target prioritization (`bounty.js`)
  - **Threshold** — evaluation thresholds (`threshold.js`)
- **Card intent** system (`server/ai/card_intent/`) — card-specific AI knowledge
- **Lethal checks** — dedicated lethal-finding logic

### SDK Agents (`app/sdk/agents/`)
- `baseAgent.coffee` — abstract agent helper for tagging units and gathering action sequences
- `staticAgent.coffee`, `agentActions.coffee` — thin SDK-side utilities
- `GameSession.setAiDifficulty()` / `getAiDifficulty()` for difficulty configuration

---

## Balancing Architecture

There is no single "balance manifest" or spreadsheet in the codebase. Balance is expressed through:

1. **Per-card stats** — ATK, HP, mana cost defined in factory files
2. **Modifier parameters** — buff amounts, durations, conditions in `createContextObject()` calls
3. **Global constants** — `config.js` defines board size, mana curve, movement speeds, attack ranges, deck limits
4. **Rarity gating** — deck-building constraints (max 3 copies of any card)
5. **Mana curve** — 2 starting mana, +1 per turn, cap at 9 creates a natural power progression
6. **Second player compensation** — Player 2 gets +1 starting mana

### Balancing Levers

| Lever | Where | Effect |
|-------|-------|--------|
| Card stats | Factory files | Direct power adjustment |
| Mana cost | Factory files | Tempo/curve positioning |
| Modifier parameters | Modifier `createContextObject()` | Ability strength tuning |
| Board dimensions | `config.js` | Positioning importance, game length |
| Mana cap/growth | `config.js` | Power ceiling, game pacing |
| Deck constraints | `config.js` | Consistency vs variety |
| Rarity distribution | Card definitions | Collectibility and draft balance |

---

## Additional Game Systems

### Gauntlet (Draft Mode)
Players draft a deck from semi-random card offerings, then compete. Special gauntlet cards exist in `factory/misc/gauntlet_specials.coffee`. Gauntlet deck size is 31 cards.

### Boss Battles (PvE)
Dozens of boss Generals with unique mechanics (listed in `factionFactory.coffee` under Faction 300). Boss-specific cards in `factory/misc/bosses.coffee` (~79 unique boss cards).

### Challenges (Puzzles)
Pre-set board states for puzzle-solving. Logic in `app/sdk/challenges/`.

### Rift Mode
An evolving game mode with its own progression. Redis manager at `server/redis/r-riftmanager.coffee`.

### Cosmetics
Skins, emotes, card backs tracked in the cosmetics system. `CosmeticsFactory` handles prismatic (foil) and skin variants.

### Progression
- **Daily quests** — tracked in user data
- **Faction progression** — per-faction level/XP
- **Achievements** — milestone tracking
- **Rank/ladder** — competitive ranking with season resets
- **Spirit orbs** — card pack opening system
- **Crafting** — spirit currency for creating/disenchanting cards

### Codex (Lore)
Card lore system at `app/sdk/cards/cardLore.coffee` — narrative flavor text and world-building.

---

## Asset Organization

### Sprites and Animations
- **`app/resources/units/`** — sprite sheets as `.png` + `.plist` pairs (TexturePacker format)
- **`app/resources/generals/`** — General-specific assets
- **`app/resources/fx/`** — visual effect sprites
- **`app/resources/particles/`** — particle system definitions

### Audio
- **`app/audio/`** — audio engine, music sequencing, SFX wrappers
- **`app/resources/music/`** — background music
- **`app/resources/sfx/`** — sound effects

### UI and Presentation
- **`app/resources/ui/`** — interface elements
- **`app/resources/maps/`** — battlefield backgrounds
- **`app/resources/scenes/`** — menu/screen backgrounds
- **`app/resources/card_backgrounds/`** — card art frames
- **`app/resources/emotes/`** — player emote sprites
- **`app/resources/crests/`** — faction crest images

### Asset Reference System
Cards don't reference asset files directly. Instead, `app/data/resources.js` defines an RSX (resource) manifest with logical names (e.g., `RSX.f1GeneralAttack.name`) that map to actual file paths. Cards reference these logical names, and the build pipeline resolves them.

---

## Key Code References

For any future agent picking this up:

| What | File |
|------|------|
| Game constants | `app/common/config.js` |
| Game session (core loop) | `app/sdk/gameSession.coffee` |
| Base card class | `app/sdk/cards/card.coffee` |
| Card type enum | `app/sdk/cards/cardType.coffee` |
| Entity (unit/tile base) | `app/sdk/entities/entity.coffee` |
| Unit defaults | `app/sdk/entities/unit.coffee` |
| Spell base | `app/sdk/spells/spell.coffee` |
| Artifact base | `app/sdk/artifacts/artifact.coffee` |
| Board state | `app/sdk/board.coffee` |
| Base modifier | `app/sdk/modifiers/modifier.coffee` |
| Modifier registry | `app/sdk/modifiers/modifierFactory.coffee` |
| Faction definitions | `app/sdk/cards/factionFactory.coffee` |
| Faction IDs | `app/sdk/cards/factionsLookup.coffee` |
| Rarity definitions | `app/sdk/cards/rarityLookup.coffee` |
| Card set IDs | `app/sdk/cards/cardSetLookup.coffee` |
| Example card factory | `app/sdk/cards/factory/core/faction1.coffee` |
| Server game loop | `server/game.coffee` |
| AI opponent | `server/ai/starter_ai.js`, `server/ai/phase_ii_ai.js` |
| English card strings | `app/localization/locales/en/cards.json` |
| English modifier strings | `app/localization/locales/en/modifiers.json` |
| Asset manifest | `app/data/resources.js` |
