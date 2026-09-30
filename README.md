# Stargazer ⭐

A top-down cosmic action-farming game built in **Godot 4.2** (GL Compatibility renderer).
Gather materials in a bounded astral clearing, grow crops, craft sigils and upgrades at the
Star Forge, then call a planet down onto an arena floor and fight it.

Every visual in the game is **drawn in code** — polygons, arcs, particles and tweens. There
are no sprite sheets, no downloaded art and no third-party dependencies.

> **Scope of this repository.** This is **Chapter One**: a complete, playable
> gather → grow → craft → summon → fight → reward loop with **two** multi-phase bosses and
> data-driven foundations for adding more. It is *not* a finished Calamity-sized game, and
> the "Known limitations" section below is honest about what is still missing.

---

## Requirements & running

1. Install **[Godot 4.2 or newer](https://godotengine.org/download)** (standard build; the
   .NET build is not required).
2. Open Godot → **Import** → pick `project.godot` in this folder.
3. Press **F5**. The game starts on the title screen.

From a terminal:

```bash
godot --path . # runs the project
```

The project stays on **Godot 4.2 / GL Compatibility** deliberately, so it runs on old
hardware and integrated GPUs. Because Compatibility has no glow pipeline, every "glow" in
the game is a stack of layered translucent circles (`Palette.draw_halo`) that renders
identically on every backend.

---

## Controls

| Action | Keys |
| --- | --- |
| Move | `W` `A` `S` `D` or arrow keys |
| Attack | Left mouse button or `Space` |
| Aim | Mouse (moving with the keyboard hands aim back to your facing direction) |
| Dash | `Shift` or right mouse button |
| Interact — harvest, till, plant, use the altar | `E` |
| Drink an Astral Salve | `Q` |
| Satchel & Star Forge | `C` |
| Inventory | `Tab` or `I` (opens the same panel) |
| Skip the boss introduction | `Enter` or `Space` |
| Pause / close a panel | `Esc` |

All of these are registered as real input actions in `project.godot`, so they can be
remapped from the Godot editor's *Project → Project Settings → Input Map*.

---

## Progression walkthrough

The HUD always shows the next objective, but in full:

1. **Gather.** Press `E` on **Sky Crystals** (stardust), **Voidstone Boulders** (voidstone)
   and **Emberseed Shrubs** (emberseeds). Nodes deplete after one or two hits and **regrow
   after 16–22 seconds**, so you can never permanently run out of anything.
2. **Farm.** Press `E` on bare ground to till it, `E` again to plant an Emberseed. Crops
   pass through **four visible growth stages** (28 seconds total) and sprout a bright
   chevron when ripe. Harvesting yields **2 Ember Blooms and 1 Emberseed**, so a single
   seed sustains farming forever.
3. **Craft** (`C`). The Star Forge lists every recipe with its exact cost and, when you are
   short, exactly what is missing:
   | Recipe | Cost | Effect |
   | --- | --- | --- |
   | Astral Salve ×2 | 2 Ember Bloom, 1 Stardust | Heals 40 HP (`Q`) |
   | Cinder Sigil | 4 Stardust, 3 Voidstone, 2 Ember Bloom | Summons Mars |
   | Starforged Edge | 8 Stardust, 4 Voidstone | +10 melee damage (once) |
   | Astral Vitality | 5 Ember Bloom, 6 Voidstone | +40 max health (once) |
   | Void Lining | 1 Cinder Core, 8 Voidstone, 6 Stardust | +20 HP, +4 damage (after Mars) |
   | Ring Sigil | 2 Cinder Cores, 6 Stardust, 4 Voidstone | Summons Saturn (after Mars) |
4. **Summon.** Walk to the **Altar of Distant Suns** (north of spawn) and press `E`. The
   panel shows both encounters, their offering and why a locked one is locked.
5. **Fight Mars, The Cinder Warlord**, then **Saturn, The Ringbound Sovereign**. Victory
   pays out materials and records the defeat permanently; both bosses can be re-challenged
   as often as you like by crafting another sigil.

A first Mars attempt needs one crop cycle plus a short gathering trip — a few minutes from
a new game, not an evening of grinding.

---

## The bosses

Both encounters use the same data-driven `BossBase` scheduler (windup → active → recovery,
with a guaranteed opening after every pattern) but share no artwork, silhouette or attack.

### Mars — *The Cinder Warlord* (620 HP, 2 phases)
A cracked crimson core inside four armour plates, ringed by orbiting fragments. Aggressive
and close-range.

| Phase | Patterns |
| --- | --- |
| 1 | **Charge** — a beam telegraph for 0.85s, then a 620 px/s dash. **Meteors** — five circular impact warnings that detonate after 1.15s. |
| 2 | Plates separate and the fissures widen. Adds **Fissure** — three expanding ember rings, each with a gap to run through — and **Fragments** — a six-shot spread fired from the orbiting debris, which visibly depletes as it fires. |

### Saturn — *The Ringbound Sovereign* (900 HP, 2 phases)
A large banded sphere with a crowned slit of light and three independently animated orbital
rings. Slow, imperious, and fought at range.

| Phase | Patterns |
| --- | --- |
| 1 | **Ring Fan** — rotating three-spoke volleys whose rotation direction is readable from the ring stones. **Ring Blades** — heavy boomerang blades that return through your position. |
| 2 | The rings **detach** and gain their own axes. Adds **Sweep** — two counter-rotating streams — and **Collapse** — a 26-orb ring that contracts inward with exactly one gap, preceded by a 0.9s warning. |

Difficulty is meant to be hard but learnable: every attack has a visible windup, every
pattern ends in a recovery window, and nothing is unavoidable. Telegraphs are drawn with a
dark fill and a bright rim at `z_index = 20`, so they stay readable over any scenery.

---

## Feature list

**World & resources**
- Bounded 46 × 30 tile clearing with a safe spawn plaza and a hard void border.
- Up to 34 renewable resource nodes (12 crystals, 12 boulders, 10 shrubs) with hit
  counts, depletion, respawn timers and regrowth.
- Tillable soil with persistent tilled cells and four-stage crop growth.
- Dozens of pieces of procedural scenery (spires, shards, moss, blooms, monoliths),
  seeded so the layout is identical every run, with depth sorting.

**Combat**
- Three-part melee: 0.07s windup, 0.12s active arc (105°, 62 px), 0.16s recovery.
- Mouse aiming that automatically defers to the keyboard when you move with `WASD`.
- Dash: 0.16s at 720 px/s with 0.26s of invulnerability and a 1.1s cooldown, shown on the HUD.
- 0.75s hurt invulnerability, knockback from the real damage source, and healing consumables.
- Projectiles are globally capped (220 live at once) and despawn outside the arena.

**Interface**
- Title screen with **Continue** shown only when a save exists, and a confirmation prompt
  before a new game overwrites it.
- HUD: health, dash meter, carried materials, contextual prompt, objective and notices.
- Satchel & Star Forge, altar summoning panel, pause menu with the full control reference.
- Boss HUD with the boss's name, title, health and phase pips; skippable introduction;
  victory and death overlays with rewards and two clear exits.
- Settings (effects volume, music volume, screen shake, reduced flashing, damage numbers)
  shared between the title screen and the pause menu, saved immediately.

**Persistence**
- Versioned JSON save at `user://stargazer_save.json` with a `.bak.json` backup.
- Inventory, upgrades, progression flags, tilled soil, crop timers and settings are saved.
- A missing, truncated or malformed save falls back to safe defaults instead of crashing;
  every field is individually sanitised on load.
- A queued encounter is cleared when it is read, so reloading can never resurrect a
  half-finished boss fight, and `EncounterState.consume_victory()` makes double rewards
  impossible.

---

## Tests

Two executable suites, both runnable headlessly. **Both were run against Godot 4.2.2 while
developing this change and both pass.**

```bash
# 1. Pure logic: inventory, crafting, crops, progression, save/load, corruption, encounters
godot --headless --path . --script res://tests/run_tests.gd     # 123 assertions

# 2. Integration: boots the real scenes with the real autoloads
godot --headless --path . res://tests/SmokeTest.tscn            # 77 assertions
```

The smoke test plays the chapter: it tills, plants, grows and harvests a crop, mines a
crystal, crafts, summons Mars, drives the fight through its phase change, kills it, checks
the rewards and that no projectile or telegraph leaked, re-summons and *dies* to verify the
death cleanup, unlocks and clears Saturn, reloads from disk, and finally asserts that every
overlay panel fits inside the viewport at 1280×720, 1600×900 and 1920×1080.

Import and boot were also verified:

```bash
godot --headless --path . --import       # run twice on a cold checkout, see note below
godot --headless --path . --quit-after 120 res://scenes/World.tscn
```

> On a fresh clone the **first** `--import` can report `Identifier ... not declared` because
> the global class cache does not exist yet. Running it a second time resolves it. Opening
> the project in the editor does this for you.

### Manual playtest checklist

Automated tests cannot judge how the game *feels*. Please check by hand:

1. Title → **New Game** → the clearing fades in, the objective reads "Harvest…".
2. Mine a crystal and a boulder; confirm the pop, the floating `+N` and the HUD counters.
3. Till, plant, wait ~30s and harvest; confirm the four growth stages are distinguishable.
4. `C` → craft a salve and a Cinder Sigil; confirm locked recipes explain themselves and
   that clicking a button never also swings your blade.
5. `E` at the altar → summon Mars. Skip the intro with `Enter`; confirm it is instant.
6. Fight: confirm charge and meteor telegraphs are readable, that dashing through an attack
   grants i-frames, and that the phase change banner fires at 55% health.
7. Die on purpose; confirm every projectile vanishes and the retry/return buttons work.
8. Win; confirm the reward list, the banner back in the hub, and that Saturn has unlocked.
9. `Esc` mid-fight; confirm the game truly pauses and resumes.
10. Resize the window to 1280×720 and 1920×1080 with panels open; confirm nothing clips.
11. Quit to title and press **Continue**; confirm your materials and defeats survived.

---

## Project structure

```
project.godot            # Godot 4.2, GL Compatibility, input map, autoloads
scenes/
  ui/TitleScreen.tscn    # main scene
  World.tscn             # the hub clearing
  BossArena.tscn         # the encounter scene
  Player.tscn
  bosses/Mars.tscn, bosses/Saturn.tscn
scripts/
  core/                  # engine-independent game logic (unit tested)
    GameData.gd          # items, recipes, upgrades, crops, nodes, bosses, objectives
    GameStateData.gd     # inventory, crafting, farming, progression, serialisation
    SaveIO.gd            # versioned user:// save with a backup
    EncounterState.gd    # boss health, phases and lifecycle
    GameState.gd         # autoload wrapper + signals + scene hand-off
    Palette.gd           # the cosmic colour identity and Compatibility-safe halos
  entities/              # Player.gd, PlayerArt.gd
  world/                 # World.gd, GroundRenderer.gd, ResourceNode.gd, Altar.gd,
                         # Prop.gd, ArenaFloor.gd, BossArena.gd
  bosses/                # BossBase.gd + MarsBoss/MarsArt, SaturnBoss/SaturnArt
  fx/                    # Projectile, Telegraph, SlashEffect, DamageNumber, ImpactFX, Starfield
  ui/                    # UIKit, HUD, BossHUD, panels, menus, overlays
  Juice.gd               # the original flash/shake/pop helper, kept as-is
tests/                   # run_tests.gd (logic) and SmokeTest.tscn (integration)
```

The `core` layer never touches the scene tree, which is what makes it testable without a
window. The game layer reads from it and draws.

---

## Art approach

- **Everything is procedural.** Each visual is a `_draw()` implementation built from
  polygons, arcs, polylines and circles, animated by accumulating `delta` and by tweens.
  There are no image assets besides the existing `icon.svg`.
- **One palette.** `Palette.gd` holds the whole identity: deep indigo/violet ground, a
  restrained cyan and gold for highlights, crimson reserved for danger. Bosses tint
  themselves from their data entry's `accent`.
- **Readability first.** Shadows are drawn beneath every actor, props and actors are depth
  sorted by `z_index = y`, telegraphs sit above the world at `z_index = 20`, and the arena
  rim pulses so the boundary is never ambiguous.
- **No Compatibility-incompatible effects.** No `WorldEnvironment` glow, no shaders.
  `Palette.draw_halo()` fakes bloom with stacked translucent circles.
- **Accessibility.** Screen shake is scaled by a setting (and can be switched off), a
  *reduced flashing* option exists, and damage numbers can be hidden.

## Adding another boss

The encounter layer is data-driven; a third planet needs three things.

1. **Data** — append an entry to `GameData.BOSSES` (id, name, title, scene path, sigil item,
   `requires` flag, `defeat_flag`, reward bundle, intro line, accent colour) and, if it
   needs a new summoning item, add it to `ITEMS` plus a recipe in `RECIPES`.
2. **Script** — `extends BossBase` and implement `patterns()`, `_begin_pattern()`,
   `_tick_pattern()`, `_idle_move()` and `_on_phase()`. `shoot()` and `Telegraph` handle
   projectiles, arena bounds and warnings for you; lifecycle, phases, contact damage,
   death and hazard cleanup are inherited.
3. **Scene** — copy `scenes/bosses/Mars.tscn`, point it at the new script and a new
   `_draw()`-based art node, and set `boss_id`, `max_health`, `phase_thresholds`,
   `move_speed`, `contact_damage` and `body_radius` in the inspector.

No other file needs editing: the altar, the summon panel, the objectives text, the boss HUD
and the save format all read from `GameData`.

---

## Known limitations

Stated plainly, because the point of this chapter is to be honest about what exists:

- **There is no audio.** The volume sliders are stored and applied to nothing. Any future
  sound must be original or properly licensed.
- **Two bosses only.** Mars and Saturn. The roster is not Calamity-sized.
- **The hub is a single clearing.** There is no world generation, no biomes, no mining
  depth, no NPCs and no building.
- **No controller support or key rebinding UI.** Actions are remappable from the editor only.
- **Animation is procedural, not hand-keyed.** It is consistent and readable, but it is not
  frame-by-frame sprite animation and it will not look like hand-drawn pixel art.
- **Balance has been reasoned about, not playtested by a human.** Numbers were verified to
  be survivable and the fights were driven to completion headlessly, but the difficulty
  curve will want tuning once you have actually played it.
- **Automated validation cannot judge feel.** Please run the manual checklist above.
