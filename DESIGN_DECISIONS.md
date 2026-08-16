# XenoHeart — Design Decisions

Every tunable in `balance.json` is documented here with its rationale and the
range we'd accept. Change the value, not the code — the whole game reads from
this one file.

## World & worldgen (`world`)

| Key | Default | Why |
|-----|---------|-----|
| `seed` | `1337` | Any int; the seed is the *only* input to base terrain. Override at runtime via the `SEED` localStorage key if you want a fresh world. Same seed → same world (verified by `tests/run_tests.gd`). |
| `chunk_radius` | `13` | Radius (hexes) of one chunk. 13 is large enough that a chunk never fully fits on screen, so the view window straddles ~9 chunks and generation stays smooth as the player moves. |
| `chunk_view_window` | `4` | Chunks generated around the player, at `chunk_radius` spacing. 4 → keeps the visible hex buffer ~2 chunks ahead on each side before the next chunk gen kicks in. |
| `spawn_clear_radius` | `8` | Radius around (0,0) that is guaranteed walkable (trees/ores/chests/hills/ocean are suppressed) so the player always has a clear start. |
| `village_spacing` | `22` | Villages tile on a hex lattice spaced 22 apart. Roughly one village per ~240 chunks of world — frequent enough that you meet one within a couple of minutes, rare enough to feel like a destination. |
| `dark_noise_threshold` | `0.22` | Dark zones are where fBm noise > 0.22. Tuned low because our noise amplitude is modest (see below) — we want ~30–40% of the map to be dark. |
| `dark_min_area` | `14` | Minimum number of hexes a dark zone must contain before it is considered "a zone" (avoids 1-hex specks that spawn a crystal for nothing). |
| `ocean_noise_threshold` | `0.345` | Sea where noise > 0.345. Slightly above the dark threshold so oceans are a subset of the high-noise ridges — they read as "the loud places". |
| `hill_noise_threshold` | `0.29` | Impassable walls where noise > 0.29. Between dark and ocean so hills and oceans interleave but don't fully overlap. |

**Why the thresholds are so low:** our `FbmNoise` (4-octave value noise) has a
natural output range of roughly `[-0.25, +0.25]` for the frequency we sample
at, not `[-1, +1]`. The thresholds are therefore calibrated to that observed
range (see `tools/calibrate_noise.py` if you change the octaves or base
frequency). If you bump the octaves, re-run the calibration and update these
three numbers together.

| `tree_chance` | `0.14` | Trees are the common resource. 14% of walkable grass → wood is easy to find early. |
| `ore_chance` | `0.02` | Rare ore is the *medium-difficulty* gate. 2% means ~1 ore per 50 walkable hexes — you have to wander or hunt. |
| `chest_chance` | `0.004` | Chests are rare windfalls. 0.4% → ~1 per 250 hexes. |
| `chest_min_dist_from_spawn` | `6` | Don't clutter the start. |
| `ore_min_dist_from_spawn` | `5` | Same. |

## Ticks (`ticks`)

| `tick_seconds` | `0.7` | **Spec-mandated**: 1 tick per 0.7 s. The whole game is a discrete tick machine; this is the clock. |
| `auto_save_every_ticks` | `50` | **Spec**: save every 50 ticks (~35 s) in addition to on-pause. |

## Player (`player`)

| `base_hp` | `2` | **Spec**: without armor, 2 HP. One zombie hit = death, which makes the low-HP red screen the constant threat. |
| `armor_hp_bonus` | none 0 / leather 2 / steel 5 / ultimate 10 | Armor *adds to* max HP (spec: "armor increases health points"). The jumps are big enough to feel like real protection (2→7→12→22) but the ultimate still requires 1 crystal. |
| `hp_regen_seconds_since_hit` | `20.0` | **Spec**: HP auto-replenishes after 20 s without a hit. |
| `hp_regen_per_second` | `1.0` | Full regen in 2 HP at base → 2 s. Fast enough that a 20-s no-hit window fully heals you, so "stop getting hit" is the actual survival mechanic. |
| `base_damage` | `1` | Bare hands hit for 1 — enough to kill a wolf (2 HP) in 2 ticks, a zombie (3 HP) in 3. |

## Weapons (`weapons`)

Each weapon is `(damage, reach, pattern)`:
- `face` = the single hex you're facing (sword/spear).
- `front3` = a 3-hex frontal arc (axe/ultimate_sword).
- `all6` = all 6 neighbors (hammer — high damage, slow-feel via 6-way coverage).
- `reach` = how many hexes out the pattern extends.

| Weapon | dmg | reach | pattern | Notes |
|--------|-----|-------|---------|-------|
| `none` (fists) | 0 | 0 | none | Default. You can't fight; you run and rotate. |
| `sword` | 2 | 1 | face | First real weapon. Cheap. |
| `spear` | 1 | 2 | face | Low damage, long reach — poke. |
| `axe` | 2 | 1 | front3 | Wide, same tick as sword. |
| `hammer` | 3 | 1 | all6 | Highest single-target damage, but "slow" because it hits everything (you can't focus a flank). |
| `ultimate_sword` | 4 | 2 | front3 | Crystal weapon. Wide + long + hard. |
| `ultimate_spear` | 2 | 3 | face | Crystal weapon. Longest reach. |

The combat feel (spec: "tower-defense-meets-dogfight") comes from **facing =
sword** + **instant rotation between ticks** + **auto-attack on the faced hex**.
You rotate to intercept threats, not to aim.

## Enemies (`enemies`)

| `zombie` | hp 3, dmg 1, 1 hex/tick | **Spec**: follows the player, attacks head-on. Slower in a fight than the player can kite. |
| `wolf` | hp 2, dmg 1, 1 hex/tick | **Spec**: walks sideways or head-on, attacks only head-on. Harder to kill (2 HP) but fragile to a well-aimed swing. |

`spawn_weight` 60/40 → zombies are the common threat, wolves the spice.

## Spawns (`spawns`)

| `max_active_enemies` | `20` | **Spec/benchmark**: 20 active is the 60fps target. |
| `max_active_enemies_far` | `30` | Bump to 30 when you're deep in a dark zone (more threat density where it matters). |
| `spawn_check_every_ticks` | `3` | Don't roll spawns every tick (20 enemies × spawn-roll every 0.7 s is wasteful). Every 3 ticks. |
| `spawn_radius` | `14` | Spawn within 14 hexes of the player (just outside the visible ring) so enemies enter the screen, not pop in on it. |
| `despawn_radius` | `26` | Despawn beyond 26 (well off-screen) to bound the entity count. |
| `min_player_dark_or_near` | `true` | **Spec**: enemies spawn only in/around dark areas. If the player is not near dark, no spawns. |

## Loot (`loot`)

`chest_table` is a weighted list; each chest rolls **exactly one** item
(spec: "always contains only 1 item").

| item | qty | weight | Note |
|------|-----|--------|------|
| wood | 2–5 | 30 | Common filler. |
| rare_ore | 1–2 | 25 | The medium gate. |
| rare_stone | 1 | 15 | Cosmetic/quest reward. |
| leather_armor | 1 | 10 | First armor drop. |
| sword | 1 | 10 | First weapon drop. |
| spear | 1 | 8 | |
| axe | 1 | 7 | |
| hammer | 1 | 5 | |
| ultimate_sword | 1 | 2 | Crystal-grade; also craftable. |
| ultimate_spear | 1 | 1 | Crystal-grade; also craftable. |

`crystal_loot`: breaking a darkness crystal gives **1 `darkness_crystal`**
(spec). 1 crystal = ultimate armor, 2 = ultimate sword (via `crafting` below).

`tree_wood` `[1,2]`, `ore_yield` `1`: a tree gives 1–2 wood on a bump, an ore node gives 1.

## Crafting (`crafting`)

Material cost per item. The "medium difficulty" is the **ore** requirement
(2% world spawn rate) — wood is trivial, ore is the grind, crystals are the
endgame (only from dark zones).

| Item | wood | rare_ore | darkness_crystal |
|------|------|----------|------------------|
| leather_armor | 5 | 2 | 0 |
| steel_armor | 4 | 6 | 0 |
| ultimate_armor | 10 | 10 | **1** |
| sword | 4 | 3 | 0 |
| spear | 6 | 1 | 0 |
| axe | 7 | 2 | 0 |
| hammer | 8 | 5 | 0 |
| ultimate_sword | 15 | 15 | **2** |
| ultimate_spear | 12 | 8 | **2** |

## Quests (`quests`)

| `max_active` | `3` | Three concurrent sidequests is a good "busy but not a to-do list" number. |
| `fetch_qty_min` / `fetch_qty_max` | `3` / `6` | Fetch 3–6 of an item. |
| `defeat_count_min` / `defeat_count_max` | `2` / `4` | Defeat 2–4 of a monster type. |
| `rewards` | per-type | Fetch wood → ore, fetch ore → stone, defeat zombie → wood, defeat wolf → stone. Rewards lean toward the *scarce* resource so a quest is worth doing. |

## Villagers (`villagers`)

| `per_village` | `1`–`2` | Each village has 1–2 villagers. |
| `offered` | trade 0.45 / quest 0.35 / none 0.20 | **Spec**: a villager offers a trade OR a sidequest OR nothing. 20% do nothing (a quiet, humming villager). |
| `trade_wood_for_ore` | give 4 wood → get 1 ore | A trade is an *alternative* ore source (faster than mining, but you're paying with your common resource). |

## Content (`content.json`)

Generated by the local `unsloth/Qwen3.8-27B-NVFP4` model (see the session
log): villager names, fetch/defeat quest flavor lines, and ambient flavor text.
It's deterministic content (loaded from disk, not re-rolled), so it's part of
the "seeded" experience.

## What is deliberately NOT tunable

- **Hex geometry** (axial pointy-top) — it's structural, lives in `core/hex_util.gd`.
- **Save format version** — lives in `SaveSystem`.
- **The 3-button control scheme** — spec-mandated; changing it is a re-design, not a balance tweak.
