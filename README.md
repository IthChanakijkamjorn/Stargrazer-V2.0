# Stargazer ⭐

A 2D **top-down** (Core Keeper style) action-farming game built in **Godot 4**. Explore, farm, and fight **star & planet-themed bosses** — Saturn, the Sun, and more to come.

> This repository contains a **runnable base game**: 8-directional movement, a follow camera, a tile-based world, basic interaction/farming, and a placeholder **Saturn** boss with aggro + a health bar. Everything uses simple colored shapes so it runs with **no external art**.

## Why Godot 4?

For a 2D Terraria/Core Keeper-style game, Godot 4 is the best fit: it's free, open-source, lightweight, and **2D-first**. You get `TileMap`, `CharacterBody2D`, and an animation system out of the box, with instant iteration (no long compiles).

## Run it

1. Install **[Godot 4.2 or newer](https://godotengine.org/download)** (the standard, non-.NET build is fine).
2. Open Godot → **Import** → select the `project.godot` file in this folder.
3. Press **F5** (or the ▶ Play button).

## Controls

| Action | Key |
|--------|-----|
| Move | `WASD` or Arrow keys |
| Interact / Till soil | `E` |
| Attack | `Space` |

Walk up to **Saturn** (the purple ringed circle). Get close and it will aggro and chase you — press `Space` while facing it to deal damage and watch its health bar drop. Press `E` on empty ground to till soil (it turns brown).

## Project structure

```
Stargrazer-V2.0/
├─ project.godot          # Godot project config + input map
├─ icon.svg              # App icon
├─ scenes/
│  ├─ World.tscn         # Main scene (run target)
│  ├─ Player.tscn        # Player with camera + interact area
│  └─ Boss.tscn          # Saturn boss
└─ scripts/
   ├─ World.gd           # World gen + farming/tilling
   ├─ Player.gd          # Movement, interaction, attack
   └─ Boss.gd            # Boss AI (idle → aggro → chase)
```

## Roadmap ideas

- [ ] Replace colored shapes with pixel-art sprites + animations
- [ ] More bosses: **Sun** (fire/projectiles), **Neptune** (water waves), **Mars** (charge attacks)
- [ ] Crops that grow over time on tilled soil
- [ ] Inventory + items + mining
- [ ] Boss arenas you enter from the overworld

---

Made as a starting point for **Stargazer**. Have fun, and tweak freely!
