# ExitRoom: project files

Open `project.godot` with **Godot 4.7.2**. F5 opens `main_menu.tscn`.

Each level lives in its own folder under `levels/`, like Room 407 always did:
the level scene sits at the folder root, with `scripts/`, `assets/` and `audio/`
inside when the level has its own. Code and resources used by more than one
level stay in the shared folders.

```
levels/
├── 01_last_visit/     prologue_village.tscn · scripts/prologue.gd
├── 02_after_hours/    backrooms_level.tscn · scripts/backrooms_level.gd · assets/original_backrooms.glb
├── 03_room407/        main.tscn · scripts/ · assets/ · audio/ · tools/ · licenses/
├── 04_passenger/      frog_chapter.tscn · frog_field_world.tscn · scripts/frog_chapter.gd · audio/
├── 05_realization/    forest_chapter.tscn · forest_world.tscn · scripts/ (forest_chapter, pladuk_shoulder, head_tilt)
│                      assets/psx_forest/ · assets/pladuk.glb · audio/
└── 06_dream_field/    dream_field.tscn · scenes/ (world, cat_statue) · scripts/dream_field*.gd · assets/ · audio/
```

| Folder / file | Purpose |
| --- | --- |
| `main_menu.tscn`, `scripts/anthology*.gd`, `scripts/main_menu.gd` | Episode menu, transitions, preferences and endings |
| `levels/` | One folder per level (see above) |
| `scripts/` | Shared code: player, anthology, menu, credits, spider, nav grid and the protected frog system (`frog_*.gd`, `player_struggle_pose.gd`) |
| `frog_test.tscn`, `NotoSansThai.ttf` | Protected frog test scene and the font it loads; both must stay at the root |
| `assets/models/`, `assets/textures/`, `assets/shaders/`, `assets/abandoned_house_*` | Shared models (player, frog, spider) and textures used by several levels |
| `Grass/`, `tree/` | Binbun grass shader and the dead tree model |
| `audio/anthology/`, `audio/spider/`, `audio/*.wav` | Menu/UI sound, spider sounds and shared footsteps |
| `ui/fonts/`, `ui/previews/`, `ui/menu_film.gdshader` | Bundled fonts, episode thumbnails and menu effect |
| `scripts/credits_data.gd`, `scripts/end_credits.gd` | Credits list shared by the menu page and the end roll after Level 06 |
| `scenes/dev/` | Sandbox scenes for trying models (not part of the game) |
| `tests/`, `tools/` | Development checks and scene generators; excluded from the web game |
| `docs/` | Story (`STORY.md`), handoff notes, per-episode notes and this layout |
| `README.md`, `ASSET_CREDITS.md`, `CLAUDE.md` | Overview, asset credits and agent notes |
| `.github/workflows/web.yml`, `export_presets.cfg` | Web export and GitHub Pages deployment |
| `.godot/`, `.buildtmp/`, `build/` | Local generated files; never commit (`.buildtmp/` has a `.gdignore`) |
| `source_assets/`, `assets_src/`, downloaded PSX packs | Local source/reference packs, ignored by Godot (`.gdignore`) and Git |

The frog system keeps its original paths so its protection checks stay valid. The web menu uses the existing Passenger photo; the native
menu keeps the 3D backdrop. The episode itself still uses the original grass world.
Web limits grass drawing to 96 blades per chunk within 36 metres; the original
scene resources and the native game's grass density are unchanged.

## Source library and removed prototypes

Unused asset packs, Blender/FBX sources, obsolete models/scenes, presentation
files, screenshots and the optional Godot AI editor plugin were moved out of this
checkout. The local backup is beside it at:

`../ExitRoom_SourceLibrary/2026-10-09/`

`archive-manifest.json` lists the formerly tracked files. They also remain in Git
history. Nothing in this backup is imported into or published with the game.
Restore a source pack from there when needed, then export only its final resources
into the game. Original build tools are kept for reference; tools that consume
archived source models require those sources to be restored before use.

## Publishing

The Web preset exports a list of runtime resources rather than every file in the
project. Add new dynamically constructed resource paths to that list in Godot's
Export dialog. Fonts, all episode scenes, previews and dynamic sound effects are
explicitly selected; model and shader dependencies are included as well.

The workflow imports with Godot 4.7.2, runs `tools/verify_release.gd`, exports, and
runs the check again against the actual PCK. A missing font, chapter or sound must
fail the build before GitHub Pages publishes it. On Web, fullscreen is requested
from a click or key gesture and Esc exits it. Closing a game on Web means closing
the browser tab, so its menu offers fullscreen instead of stopping the engine.
