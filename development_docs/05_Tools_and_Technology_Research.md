# Tools & Technology Research

Research on modern tools, AI-powered game development workflows, and open-source frameworks relevant to building on or evolving the Duelyst codebase.

---

## 1. AI-Powered Sprite-to-3D Conversion

One compelling direction: take Duelyst's pixel art sprites and use AI to generate 3D models from them — either for a 3D remaster or for use in a new game.

### Dedicated Game Asset Platforms

**[Sprixen](https://sprixen.com/)** — AI game asset generator purpose-built for game development.
- Style-locked sprite generation for visual consistency across bulk assets
- Automated animation pipeline (walk cycles, attacks, idle)
- One-click isometric turnaround (8-direction views from a single sprite)
- Direct export to Godot, Unity, Unreal, GameMaker
- Built-in pixel editor and in-browser gameplay testing
- **Relevance:** Could maintain Duelyst's pixel art style while generating variants, or produce sprite sheets for new cards/units

**[Meshy AI](https://meshy.ai/)** — Leading image-to-3D conversion platform.
- Image-to-3D model generation in ~1 minute
- Latest Meshy 6 model: up to 600K faces, high detail
- Full PBR texture output: Diffuse, Roughness, Metallic, Normal maps
- Export formats: GLB, OBJ, FBX, STL, USDZ, Blend
- **Relevance:** Could take Duelyst unit sprites/concept art and generate 3D character models. The CC0 art assets provide a massive library of reference images.

**[Tripo3D](https://www.tripo3d.ai/)** — Fast character mesh generation with real-time iteration.
- Smart mesh real-time generation — dozens of variants in seconds
- Compresses traditional modeling pipeline (base mesh → sculpt → retopology) into a single step
- Good for rapid character prototyping
- **Relevance:** Quick iteration on character designs. Take Duelyst general/unit art, generate 3D variants, iterate rapidly.

**[Rodin (HyperHuman)](https://hyperhuman.deemos.com/)** — API-driven 3D generation.
- Optimized for organic characters with high anatomical detail
- Output resembles ZBrush sculpts (high-density meshes)
- Requires polygon decimation post-generation for game use
- API-first design for pipeline integration
- **Relevance:** Highest quality output for character models, but needs more post-processing.

### Recommended Workflow: Sprite → 3D Pipeline

Based on 2026 best practices, the professional pipeline is:

```
Duelyst Pixel Art (CC0)
    → Upscale/enhance with AI (e.g., Topaz, ESRGAN)
    → Use as reference image for Meshy/Tripo3D
    → Generate 3D model
    → Clean up in Blender (quad remeshing, UV optimization)
    → Rig and animate (Mixamo for humanoids, or manual)
    → Export to game engine (GLB/FBX)
```

**Key insight:** Image-to-3D is now preferred over text-to-3D for game assets. Using the existing Duelyst concept art and sprites as reference images gives AI models much better guidance than text descriptions alone.

---

## 2. Modern Web Game Engines

Evaluated for replacing Cocos2d-JS in a modernized Duelyst client.

### Tier 1: Best Fits

**[Phaser 4](https://phaser.io/)** — Full 2D game framework
- **Status:** Release Candidate 7 (March 2026), actively developed
- **Stack:** TypeScript-first, WebGL + Canvas fallback
- **Size:** ~1.2MB minified
- **Features:** Built-in physics, scene management, input handling, audio, tweens, particle systems, tile maps, cameras
- **New in v4:** RenderNode architecture (modular, debuggable rendering), optimized GL drawing with index buffers, shader system requesting only needed texture units (better mobile perf)
- **Migration from v3:** Breaking changes documented in [migration guide](https://phaser.io/news/2026/04/migrating-from-phaser-3-to-phaser-4-what-you-need-to-know)
- **Why for Duelyst:** Complete game framework means less custom code for input, animation, audio, scenes. The tactical board, card animations, and UI could all be built in Phaser. Strong community and documentation.

**[PixiJS v8](https://pixijs.com/)** — High-performance 2D rendering
- **Status:** Stable, unified single-package architecture
- **Stack:** TypeScript, WebGL 2 + WebGPU + Canvas
- **Size:** ~450KB minified (significantly smaller than Phaser)
- **Features:** Pure rendering: sprites, text, graphics, filters/shaders, masks, particle effects
- **Architecture:** Runtime extension system (replaced old 30+ npm package monorepo)
- **Why for Duelyst:** If you want maximum control and smallest bundle. You'd build game systems (scenes, input, audio) yourself, but the rendering would be faster. Best paired with a UI framework (React/Svelte) for menus.

### Tier 2: Viable Alternatives

**[Excalibur](https://excaliburjs.com/)** — TypeScript-native 2D game engine
- 2,255 GitHub stars, active development (v0.32.0, Dec 2025)
- Full HTML5 Canvas support, cross-platform
- Clean TypeScript API, good documentation
- Smaller community than Phaser but solid engineering

**[Conquistador](https://github.com/s3hq4y/conquistador)** — Hexagonal strategy game engine
- Built with PlayCanvas 2D, TypeScript, Vue 3, Vite
- Hex grid with axial coordinates, turn-based combat, AI opponent
- Created Feb 2026 — very new but architecturally interesting
- Directly relevant for tactical board game development

### Tier 3: Heavier Options

**[PlayCanvas](https://playcanvas.com/)** — Full 3D/2D engine with web editor
- Overkill for a 2D card game unless going 3D
- Good ECS architecture, would be relevant if pursuing the 3D remaster path

**[Godot (Web export)](https://godotengine.org/)** — Full game engine with HTML5 export
- Feature-complete but heavier than native web solutions
- Better for desktop-first games that also target web

### Recommendation

**For staying 2D (faithful to original):** Phaser 4 — fastest path to a working game, most built-in features.

**For maximum flexibility / going 3D later:** PixiJS v8 for rendering + React for UI + custom game systems — more work upfront but more control.

**For experimenting with 3D remaster:** PlayCanvas or Three.js + React Three Fiber.

---

## 3. AI Game Development Tools

### Card Game Frameworks

**[Cardiverse](https://github.com/danruili/Cardiverse)** — LLM-powered card game prototyping
- Generates novel card game variants using graph-based game mechanic indexing
- Produces validated game code from LLM output
- Builds gameplay AI through self-play optimization
- Includes LLM Gameplay AI Arena (random, human, chain-of-thought, ReAct, Reflexion agents)
- Python-based, presented at EMNLP 2025, actively maintained as of March 2026
- **Relevance:** Could be used to prototype new card mechanics or generate balanced card designs. The self-play optimization is interesting for automated balancing.

**[TCG Engines](https://github.com/TheCardGoat/tcg-engines)** — TypeScript declarative card game framework
- Immutable state management, deterministic gameplay
- Type-safe, network synchronization built in
- Reference implementations of Disney Lorcana and Gundam TCGs
- **Relevance:** If building a new game engine from scratch, this TypeScript monorepo is a strong architectural reference. The immutable state + deterministic approach aligns with Duelyst's action/event-sourcing pattern.

**[Card Framework (Godot)](https://github.com/chun92/card-framework)** — Godot 4.x card game addon
- Drag-and-drop, flexible containers, JSON card data
- MIT License, production-ready with FreeCell implementation
- **Relevance:** Only relevant if going the Godot route.

**[Cardinal Codex](https://github.com/Big-Sky-Tech/Cardinal-Codex)** — Rust headless TCG engine
- Rules defined in TOML, deterministic, 14 built-in effects
- Event-based logging, comprehensive validation
- **Relevance:** Interesting architecture (rules as data, not code) but Rust may be a barrier. Worth studying for design ideas.

### AI for Game Balancing

**LLM-based playtesting:** Tools like Cardiverse's self-play arena can simulate thousands of games to identify balance issues. The approach:
1. Define card pool with stats and abilities
2. Run LLM agents (or rule-based AI) in self-play
3. Track win rates per faction, per card
4. Identify outlier cards (too strong/weak)
5. Adjust and re-test

**Relevance for Duelyst:** The existing AI system (`server/ai/`) could be extended with LLM-based agents for more sophisticated playtesting. The shared SDK means you can run simulated games entirely server-side.

### AI for Content Generation

**Card text/flavor:** LLMs can generate card names, descriptions, flavor text, and lore consistent with a game's world. The existing localization system (`app/localization/locales/en/cards.json`) provides training examples of Duelyst's voice.

**Card art:** Image generation models (Midjourney, FLUX, Stable Diffusion) can produce card art consistent with Duelyst's aesthetic. The CC0 art assets provide style reference.

**Level/puzzle design:** LLMs can generate challenge puzzles (pre-set board states) using the game rules. The existing challenge system (`app/sdk/challenges/`) provides format examples.

---

## 4. Related Open-Source Game Projects

### For Reference / Inspiration

**[Boardgame.io](https://boardgame.io/)** — Framework for turn-based games
- State management, multiplayer, AI, React integration
- Same conceptual model as Duelyst's game session (state + moves + phases)
- Could be useful reference for modernizing the game state management

**[Colyseus](https://colyseus.io/)** — Multiplayer game server framework
- Node.js, TypeScript, WebSocket-based
- Room-based architecture, state synchronization, matchmaking
- Could replace the custom Socket.IO + Redis game server with a purpose-built framework

**[Heroic Labs Nakama](https://heroiclabs.com/)** — Open-source game server
- Matchmaking, realtime multiplayer, leaderboards, chat
- Go-based but has JS/TS client SDK
- Could replace the entire server stack (API + game + matchmaking + social)

---

## 5. Development Environment & Tooling

### Build & Bundle

| Tool | Purpose | Why |
|------|---------|-----|
| **Vite** | Client bundler | Sub-second HMR, native ESM, CoffeeScript plugin available |
| **esbuild** | Server bundler | Fastest JS bundler, good for Node.js builds |
| **tsup** | Library bundler | Built on esbuild, good for packaging the SDK as a library |

### Testing

| Tool | Purpose | Why |
|------|---------|-----|
| **Vitest** | Unit/integration testing | Vite-native, compatible with Mocha tests via minimal migration |
| **Playwright** | E2E browser testing | For testing the game in a real browser |

### Code Quality

| Tool | Purpose | Why |
|------|---------|-----|
| **Biome** | Linting + formatting | Faster than ESLint + Prettier, single tool |
| **TypeScript strict mode** | Type safety | Already configured in repo's `tsconfig.json` |

---

## 6. Potential Project Directions

Based on the available tools and the Duelyst codebase, here are concrete project directions worth considering:

### Direction A: "Duelyst Classic" — Run & Preserve
- Get the game running as-is (see [03_Implementation_Plan_Run_As_Is.md](03_Implementation_Plan_Run_As_Is.md))
- Fix known bugs, improve mobile support
- Small quality-of-life improvements
- **Tools:** Current stack, Docker, Firebase
- **Effort:** Low (1–2 weekends to get running, ongoing for fixes)

### Direction B: "Duelyst Reforged" — Modernize & Deploy
- Follow the modernization plan (see [04_Implementation_Plan_Modernization.md](04_Implementation_Plan_Modernization.md))
- TypeScript migration, Firebase removal, modern client
- Deploy publicly so others can play
- **Tools:** Vite, TypeScript, Phaser 4 or PixiJS, BullMQ, JWT
- **Effort:** High (6–12 months of weekend work)

### Direction C: "New Game, Duelyst DNA" — Build Something Original
- Extract the design patterns (shared SDK, action/event-sourcing, modifier composition)
- Build a new game with original mechanics, factions, and art
- Use Duelyst's CC0 assets as placeholders during development
- Use AI tools for art generation (sprite-to-3D, style-consistent card art)
- **Tools:** TypeScript, Phaser 4 or PixiJS, TCG Engines for reference, Cardiverse for playtesting, Meshy/Tripo3D for 3D assets
- **Effort:** Very high (ongoing creative project)

### Direction D: "AI Game Lab" — Experimental
- Use the Duelyst SDK as a simulation environment
- Build AI agents that learn to play (reinforcement learning, LLM agents)
- Automated card generation and balancing via self-play
- Research project more than game development
- **Tools:** Python + Duelyst SDK (via Node bridge), Cardiverse, LLM APIs
- **Effort:** Variable (research-driven)

---

## Research Links & References

### Game Engines
- [Phaser 4 Renderer announcement](https://phaser.io/news/2026/04/phaser-4-renderer-faster-cleaner-and-built-for-modern-games)
- [Phaser 3→4 Migration Guide](https://phaser.io/news/2026/04/migrating-from-phaser-3-to-phaser-4-what-you-need-to-know)
- [PixiJS v8 Architecture](https://readoss.com/en/pixijs/pixijs/pixijs-v8-architecture-map-of-the-codebase)
- [Excalibur.js](https://github.com/excaliburjs/Excalibur/)

### AI 3D Tools
- [Meshy AI — Best AI Tools for 3D Game Assets (2026)](https://www.meshy.ai/blog/best-ai-tools-for-3d-game-assets)
- [Tripo3D — Smart Mesh Real-Time Generation](https://www.tripo3d.ai/blog/explore/smart-mesh-real-time-mesh-generation-for-rapid-iteration)
- [Text-to-Mesh 2026: Production-Ready 3D Assets](https://astraml.com/blog/text-to-mesh-production-ready)
- [Sprixen — AI Game Asset Generator](https://sprixen.com/)
- [Milo3D — Free Image-to-3D](https://milo3d.ai/)
- [3D AI Studio](https://www.3d-ai.studio/)

### Card Game Frameworks
- [Cardiverse — LLM Card Game Prototyping](https://github.com/danruili/Cardiverse)
- [TCG Engines — TypeScript TCG Framework](https://github.com/TheCardGoat/tcg-engines)
- [Cardinal Codex — Rust TCG Engine](https://github.com/Big-Sky-Tech/Cardinal-Codex)

### Game Server Frameworks
- [Boardgame.io](https://boardgame.io/)
- [Colyseus](https://colyseus.io/)
- [Nakama by Heroic Labs](https://heroiclabs.com/)
