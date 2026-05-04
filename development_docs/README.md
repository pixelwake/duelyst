# Duelyst Development Documentation

Research, analysis, and implementation planning for the OpenDuelyst codebase — a personal game development exploration project.

## What This Is

This folder contains analysis and planning artifacts for working with the OpenDuelyst open-source codebase. The goal is to document the game's architecture, mechanics, and content deeply enough that any future development session can pick up from a cold start with full context.

## Document Index

| Document | Purpose |
|----------|---------|
| [01_Architecture_Synthesis.md](01_Architecture_Synthesis.md) | Complete technical architecture — tech stack, codebase structure, key design patterns, data flow |
| [02_Game_Design_Document.md](02_Game_Design_Document.md) | Full game mechanics breakdown — factions, cards, modifiers, board, mana, win conditions, balancing |
| [03_Implementation_Plan_Run_As_Is.md](03_Implementation_Plan_Run_As_Is.md) | Step-by-step guide to getting the game running locally in its current state |
| [04_Implementation_Plan_Modernization.md](04_Implementation_Plan_Modernization.md) | Phased plan to modernize the tech stack — Firebase removal, TS migration, modern renderer |
| [05_Tools_and_Technology_Research.md](05_Tools_and_Technology_Research.md) | Research on AI game dev tools, sprite-to-3D conversion, modern engines, open-source frameworks |

## Context

- **Source repo:** [open-duelyst/duelyst](https://github.com/open-duelyst/duelyst) (CC0 1.0 Universal license)
- **This fork:** [pixelwake/duelyst](https://github.com/pixelwake/duelyst)
- **License:** CC0 — code and assets are public domain. Trademarks (the "Duelyst" name/logos) are not waived.
- **Status:** Original game shut down in 2020. Open-sourced ~2022. Last release v1.97.13 (May 2023). Community is small but the codebase is complete.

## How to Use These Docs

These documents are designed to be agent-readable — any AI coding assistant can read them cold and have enough context to start working. They're also written to be useful for human reading. Start with the Architecture Synthesis for technical context, or the Game Design Document if you're thinking about mechanics and content.
