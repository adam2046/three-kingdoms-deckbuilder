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
- Pre-production complete (design locked)
- Prototyping phase: core battle system
