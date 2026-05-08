# AGENTS.md — Three Kingdoms Deckbuilder
# AI agent context for this project.

## Project
- Name: Three Kingdoms Deckbuilder
- Engine: Godot 4.6.2 (GDScript)
- Genre: Roguelike Deckbuilder
- Theme: Three Kingdoms / 三國殺 Standard Pack
- Target: Steam (PC/Mac/Linux)
- Languages: 繁體中文, 简体中文, English

## Design Docs
- Obsidian vault: Game Development/game 1/Game 1.md
- Full design: 26 heroes, 108-card library, ally system, judgment mechanics

## Directory Structure
- scenes/   — Godot scenes (.tscn)
- scripts/  — GDScript (.gd)
- assets/   — Images, audio, fonts
- resources/ — Card data, hero data, JSON/CSV

## Key Conventions
- All card data driven from resources/cards/
- Hero abilities defined in resources/heroes/
- Use CanvasLayer for all UI
- Signals over _process() polling
- Traditional Chinese default language, switchable

## Current Status
- Prototyping phase: core battle system complete
- Strategy cards: all 8 implemented (過河拆橋, 順手牽羊, 無中生有, 決鬥, 南蠻入侵, 萬箭齊發, 桃園結義, 五穀豐登, 無懈可擊)
- Block system: 無懈可擊 grants damage absorption
- Roguelike structure: zone progression, map nodes, gold rewards, card rewards after battle
- Campfire: heals 30% HP between battles
- 3 starter heroes: 趙雲, 曹操, 孫權 (skills working)
- Next: card upgrade system, remaining 23 hero skills, full card library
