# ExitRoom: project files

Open `project.godot` with **Godot 4.7.2**. F5 opens `main_menu.tscn`.

| Folder / file | Purpose |
| --- | --- |
| `main_menu.tscn`, `scripts/anthology*.gd`, `scripts/main_menu.gd` | Episode menu, transitions, preferences and endings |
| `prologue_village.tscn` | Episode 01: The Last Visit |
| `backrooms_level.tscn` | Episode 02: After Hours |
| `Room407/main.tscn`, `Room407/scripts/`, `Room407/assets/`, `Room407/audio/` | Episode 03: Room 407 and its own resources |
| `frog_chapter.tscn`, `frog_field_world.tscn` | Episode 04: The Passenger; keep the authored world intact |
| `scripts/` | Shared player, enemies and episode story code |
| `assets/`, `3Dmodel_import/`, `tree/` | Textures and models referenced by the playable scenes |
| `Grass/` | Binbun grass shader, its include and the two grass textures |
| `ui/fonts/`, `ui/previews/`, `ui/menu_film.gdshader` | Bundled Thai fonts, episode thumbnails and menu effect |
| `audio/` | Shared and episode sound effects |
| `tests/`, `tools/` | Development checks and scene generators; excluded from the web game |
| `STORY.md`, `HANDOFF.md`, `FROG_CHAPTER.md`, `ASSET_CREDITS.md` | Story, handoff and credits |
| `.github/workflows/web.yml`, `export_presets.cfg` | Web export and GitHub Pages deployment |
| `.godot/`, `.buildtmp/`, `build/` | Local generated files; never commit |

Scene paths stay at their current locations so existing references and the frog
system remain valid. The web menu uses the existing Passenger photo; the native
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
