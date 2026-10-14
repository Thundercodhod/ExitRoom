# 3D_game_project

**Current project (2026-10-09):** use `PROJECT_LAYOUT.md` and `README.md` for the
current file structure and Web deployment. There are four independent episodes,
launched from `main_menu.tscn`, built with Godot 4.7.2. The notes below describe
older prototypes. Their scene sequence and model paths are historical; do not
apply them to the current anthology or regenerate the authored frog world.

A 3D horror-comedy escape game built in Godot 4.7, played in THIRD-PERSON
(camera behind the player, Fall Guys style).
The player must escape a floor while avoiding monsters. Monsters are original,
meme-style parody characters (no copyrighted characters).

## Workflow rule

Always present a written plan for review before writing or editing any code.

## Current state (team repo Thundercodhod/ExitRoom, branch main)

- The project is the team's ExitRoom repo (Godot 4.7, GL Compatibility): village prologue -> garden lobby -> Backrooms -> abandoned school. Main scene `res://prologue_village.tscn`.
- All four levels create the player with `CharacterBody3D.new()` + `res://scripts/player.gd`. Keep its public API: `pivot` (yaw), `camera`, `torch`, `body_visual`, `game.playing`, `set_hiding()`.
  Input actions (`forward/back/left/right/sprint/interact/flashlight`) are registered in each level script, not in project.godot.
- **Player is now third-person** (SpringArm3D camera 2.4 m behind, shoulder offset, shortens at walls) using `res://assets/models/player/main_character.glb` at real scale (1.64 m, replaces the Hazmat demo).
  Press **V** to toggle first/third person; default is `THIRD_PERSON_DEFAULT` in `player.gd`.
- Animation state: speed < 0.15 -> `idle`; < 0.6 m/s -> `walk` (speed_scale = v / 0.22); otherwise `run` (speed_scale = v / 1.98), crossfade 0.2 s.
  Gameplay speeds (walk 2.65, sprint 4.8 m/s) were left unchanged, so walking uses the run clip at ~1.34x (jog-like). A proper in-place walking clip would look better.
- Tests: `Godot --headless --path . -s tests/<name>.gd` (player_traversal, lobby_flow, prologue_flow, school_flow). All pass. After changing the GLB run `Godot --headless --path . --import`.
- Not updated yet: lobby/prologue menu copy still says Hazmat is the temporary player (the Backrooms intro was rewritten) and the control hint does not list V.

### Spider enemy (Backrooms)
- Model: `res://assets/models/enemy/spider.glb` (from "Spider_free", unrigged FBX). Rigged and animated by `assets_src/spider/build_spider.py` (run: `Blender -b --python assets_src/spider/build_spider.py`, env SPIDER_SCALE / SPIDER_PREVIEW; it exports the glb): 17 bones (Body + 8 legs x Upper/Lower), welded legs split by geometry, scale 0.5 (about 1.8 m leg span, 2.1 m long, 0.6 m tall), faces -Z, feet at y = 0.
  Clips (30 fps): `idle-loop` 3.2 s, `walk-loop` 1.2 s (planted foot 0.45 m/s), `run-loop` 0.53 s (1.49 m/s), `attack` 1.0 s (not looped). Source blend: `assets_src/spider/spider_rigged.blend`. License of the free asset is unknown: check before crediting.
- AI: `res://scripts/spider_enemy.gd` (CharacterBody3D built in code). States PATROL, CHASE, SEARCH, ATTACK, CAUGHT. Grid navigation (AStarGrid2D from physics shape queries against layer 1, cell 0.4 m, string-pulled paths), so it works with the trimesh Backrooms walls.
  Sees the player within 12 m (75 deg cone, 3.5 m all round, line of sight), hears sprinting within 8 m, ignores a hiding player (< 1.2 m). Patrol 1.1 m/s, chase 3.2 m/s (player walks 2.65, sprints 4.8). Attack within 1.5 m, hit at 0.45 s, emits `caught_player`. Gives up after 3.5 s without contact then searches 3 s.
- Wiring: `backrooms_level.gd` `setup_spider()`, caught overlay with RETRY (reloads the scene and skips the intro), HUD status turns into a warning while the spider chases. Spider starts at least 14 m from the player.
- Reuse in another level: `set_script(preload("res://scripts/spider_enemy.gd"))`, set `game`, `target`, `bounds` (XZ rect of the walkable floor), add_child, connect `caught_player`.
- Tests: `tests/spider_enemy.gd` (19 checks). Simulation check: AFK player at spawn is caught in about 15 s.


### The Frog (watcher, not a chaser)
- Model: `res://assets/models/enemy/frog.glb` (Meshy AI, rigged by Meshy, 50 bones renamed to Hips/Spine/Chest/Neck/Head/L_/R_ arms, legs, 3 fingers per hand), 1.9 m tall, faces +Z in the file (the actor rotates it so the frog faces -Z). 51k triangles, PBR textures. Clips baked by `assets_src/frog/build_frog.py` (`Blender -b --python assets_src/frog/build_frog.py`, env FROG_HEIGHT / FROG_PREVIEW): `idle` 4 s, `walk` 1.2 s (planted foot 1.5 m/s), `sit` 4 s (seat height about 0.6 m, origin stays on the floor). Source blend: `assets_src/frog/frog_rigged.blend`.
- Behaviour: `res://scripts/frog_watcher.gd` (CharacterBody3D built in code). Never attacks. Turns its head to follow the player's head (`scripts/frog_head_tracker.gd`, a SkeletonModifier3D, limit 85 deg), walks closer to look and stops at `keep_distance` (3.5 m, tolerance 0.5), backs away (walk clip played in reverse) when the player comes nearer, always faces the player. Optional path finding: set `bounds` (XZ rect) and it uses `scripts/nav_grid.gd` (same A* grid idea as the spider).
- Story hooks (HANDOFF.md): `vanish_when_seen_within(distance, delay)`, `relocate_when_unseen(point, delay)` (queue: one jump each time the player is not looking), `appear_at(point, sitting)`, `sit()` / `stand()` for the passenger seat, `is_seen()`, `face_towards(point)`; signals `vanished`, `reappeared`, `relocated`, `settled`.
- Usage: `frog.set_script(preload(...)); frog.game = level; frog.target = player; frog.position = feet position; add_child(frog)`. Tunables: `keep_distance`, `distance_tolerance`, `approach_speed` 1.3, `retreat_speed` 1.0, `approach_range` 40, `approach_enabled`, `head_tracking`, `turn_body`.
- Not placed in any level yet (HANDOFF asked to wait for the Frog chapter). Tests: `tests/frog_watcher.gd` (29 checks). Gotcha: skeleton modifiers do not keep their poses between frames, so read `frog.head_error()` (measured inside the modifier) instead of querying bone poses from outside.

## Done (older local prototype, NOT part of the team repo; kept for reference)

### Step 1: Foundation
- `res://scenes/main.tscn` (root: `Main`, Node3D)
  - `WorldEnvironment`: near-black background, dim ambient light, volumetric fog, glow, filmic tonemapping
  - `DimLight`: DirectionalLight3D, energy 0.15, blue-grey, shadows on
  - `Floor`: CSG box 40x40 m with collision, material `res://assets/materials/floor_placeholder.tres`
- Input Map (saved in project.godot):
  - `move_forward` W, `move_back` S, `move_left` A, `move_right` D
  - `sprint` Shift, `crouch` Ctrl, `interact` E, `pause` Escape
- Folders: `scenes/`, `scripts/`, `assets/`, `ui/`

### Player model (current): `res://assets/models/player/main_character.glb`
- NOT chibi anymore: realistic young-adult proportions, ~1.64 m tall (white t-shirt, dark trousers, white sneakers, dark hair)
- Rigged: one skeleton, 28 bones (Hips, Spine*, neck, Head, Shoulder/Arm/ForeArm/Hand/Hand_End, UpLeg/Leg/Foot/ToeBase). No finger bones
- Rest pose is A-pose (arms lowered 45 deg); hands were sculpted into a relaxed curl in the mesh (fingers cannot animate)
- Single material, base-color texture only (the bogus normal map from the FBX was removed)
- Blender source: `assets_src/main_character_rigged.blend`
- Animations are baked into the GLB: `idle-loop` (8.33 s), `walk-loop` (4.6 s), `run-loop` (1.23 s), 30 fps, in place (root motion removed, Hips keeps vertical bob).
  Retargeted from Mixamo-style FBX with a compensation rotation on LeftArm/RightArm for the A-pose. Loops close cleanly (last duplicate frame dropped).
  Walk clip is slow (about 0.23 m/s of original travel): tune AnimationPlayer speed_scale against movement speed to avoid foot sliding. No crouch/scared/caught clips yet.
- Backup of the earlier static (no animation) export: `assets_src/main_character_static_apose.glb`

### Legacy primitive player model (chibi, no longer used; kept only as fallback)
- `res://scenes/player/player_model.tscn` (root `PlayerModel`, ~1.1 m tall, faces -Z, feet at y=0)
- Chibi Thai high-school student (M.6 uniform): white shirt with "ม.6" badge, navy shorts, belt, white socks, dark shoes, brown hair with grey ahoge curl
- Animated by rotating/moving part pivots:
  `Hips` (pos/rot/scale) > `Body`, `Head` (> `Face/EyeL`, `Face/EyeR`, `Hair`), `ArmL`, `ArmR`, `LegL`, `LegR`
- Materials: `res://assets/materials/player/`
- `AnimationPlayer` animations: `RESET` (rest pose), `idle`, `walk`, `run`, `crouch_walk`, `scared`, `caught`, `victory`
  - Tracks animate `rotation_degrees`, Hips `position`/`scale`, and eye `scale`
  - Not every animation keys every property: switch animations through an AnimationTree
    (which blends from RESET), or reset untouched properties when switching.
  - `crouch_walk` lowers the whole body via Hips scale (1.08, 0.85, 1.08) and y 0.357.
- Superseded by `main_character.glb` (real model now available); the facial-expression idea only applied to this primitive model.

## To do (user)

- Set `res://scenes/main.tscn` as Main Scene in Project Settings > Application > Run
  (the Godot AI plugin blocks changing this setting).

## Next steps

2. Player controller (third-person): CharacterBody3D + capsule collision, instance `main_character.glb` (wrapped in a scene),
   SpringArm3D + Camera3D orbit with mouse, flashlight, stamina for sprint, interact raycast,
   AnimationTree state machine driving the model animations
3. Level blockout: rooms, corridors, hiding spots (CSG), NavigationRegion3D
4. Monster AI: state machine (patrol, investigate, chase, lose track), line-of-sight; catching player = game over
5. Escape loop: keys/fuses unlock the exit door, win screen
6. Comedy layer: absurd sound cues, silly jumpscares, funny death messages
7. UI: main menu, pause menu, stamina bar, objective tracker
