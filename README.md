# XenoHeart

Endless hex-grid exploration for **YouTube Playables**, built in **Godot 4.7**
and exported to the standard **Web (HTML5)** target with thread support
disabled.

A cute chubby anime boy auto-runs across an infinite procedurally-generated
hex meadow. You have exactly **three buttons** — rotate left, rotate right,
pause. Facing = sword: you auto-attack whatever is in the hex you're facing,
and combat becomes a matter of rotating to intercept threats. Chop trees,
mine rare ore, clear dark zones (break the darkness crystal in the middle),
trade with villagers, take sidequests, and craft gear from wood + rare ore +
crystals. No endgame — the world is endless and the seed is yours.

## Features

- **Infinite, seeded, chunked world** — pure function of the seed; per-chunk
  deltas persist mutations (broken crystals, opened chests, cleared dark).
- **Dark zones** with a darkness crystal in the middle; breaking it clears the
  zone and stops enemy spawns there.
- **Villages** with villagers offering a trade, a sidequest, or nothing.
- **Enemies** (zombies, wolves) spawn only in/around dark areas.
- **Crafting** (armor + 5 weapons + 2 crystal-grade weapons) and **equipment**
  (armor adds max HP; weapons change your attack pattern).
- **Save**: `saveData`/`loadData` via the official YouTube Playables wrapper
  when in-env; `localStorage` when standalone.
- **Code-generated ink art** (bold outlines, variable line weight) — 29
  sprites, small enough for Playables size limits.

## Layout

```
core/          hex math, seeded RNG, fBm noise, worldgen
systems/       inventory, crafting, quests, save (pure JSON)
autoloads/     game.gd (tick/combat/interactions), yt_game_wrapper.gd
scenes/        main.gd (code-built UI), world_view.gd (single-CanvasItem renderer)
tools/         gen_art.py (sprite generator)
tests/         run_tests.gd (headless unit tests), bench.tscn (60fps budget)
balance.json   ALL tunables (see DESIGN_DECISIONS.md)
content.json   Qwen-generated quest/villager/flavor content
YTGameSDK.js   official YouTube Playables JS SDK
```

## Run & test

```bash
# install Godot 4.7.1 (arm64 on the DGX Spark) and templates, then:
godot --headless --path . --import          # first import
godot --headless --path . -s res://tests/run_tests.gd   # 34 unit tests
godot --headless --path . res://tests/bench.tscn        # 20-enemy tick budget
godot --path .                                    # editor (open in window)
```

## Export (Web)

```bash
godot --headless --path . --export-release "Web" export/web/index.html
# then copy YTGameSDK.js into export/web/ (the Godot export doesn't know about it)
```

The preset (`export_presets.cfg`) is **thread support disabled** — required
for the Playables single-threaded wasm constraint.

## Boot test (headless browser)

```bash
cd export/web && python3 -m http.server 8090
# from /tmp (puppeteer + chromium):
node /tmp/xt_test.js
```
Verifies: boots with **zero console/page errors**, renders the hex world +
player + HUD, and the pause menu shows all four pages.

## Deploy

`GitHub Actions` (`.github/workflows/deploy.yml`) exports the web build on
push to `develop`/`main` and `rsync`s it to Hetzner. It reads three secrets:
`HETZNER_HOST`, `HETZNER_USER`, `HETZNER_KEY` (the private SSH key). The
remote dir is `~/xenoh/`.

### YouTube Playables

The game integrates the **official Godot wrapper**
(`YTGameSDK.js` + `autoloads/yt_game_wrapper.gd`). Inside the Playables iframe
it reports `firstFrameReady`/`gameReady`, persists via `saveData`/`loadData`,
and honors system pause/resume. The wrapper is the **Godot 4 port** of Google's
Godot-3 sample (the original uses `get_interface().set(...)`, which no longer
exists in Godot 4's `JavaScriptBridge`).

## Performance

- **Logic:** 400 real ticks with 20 active enemies = **0.37 ms/tick**
  (`tests/bench.tscn`) — ~30× under the 16.7 ms budget at 60fps.
- **Render:** the world is drawn by **one `CanvasItem`** in one pass
  (`scenes/world_view.gd`); headless SwiftShader measures 18–19 fps, which is
  software-GL-bound, not logic-bound. On a real GPU the render is trivial.

## Balance

All numbers live in `balance.json`; every one is justified in
`DESIGN_DECISIONS.md`.
