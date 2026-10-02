# Asset credits for the abandoned-house revision

## Frog field chapter

**Godot Grass Shader** by **Binbun** — https://binbun3d.itch.io/godot-grass — CC0 (license stated on the author's page). Uses the user-supplied shader and textures under `Grass/assets/BinbunGrass/src/` unchanged, with a chapter-specific material, palette and MultiMesh placement.

The field house's bedroom reuses the existing Room407 furniture and textures; its original credits remain in `Room407/ASSET_CREDITS.md`. New car/house block geometry and the procedural audio in `audio/frog_chapter/` were authored for this chapter. Frog model and animations are unchanged.

**Low-poly Furnished Abandoned House** by **NeoKG**

Source: https://sketchfab.com/3d-models/low-poly-furnished-abandoned-house-ab6c142e1c494c8e84dd82c852138501

Author: https://sketchfab.com/NeoKg

License: Creative Commons Attribution 4.0 International (CC BY 4.0)
License link: https://creativecommons.org/licenses/by/4.0/

The supplied GLB's asset metadata identifies this title, author, source and license.

The original is stored as `3Dmodel_import/low-poly_furnished_abandoned_house.glb`.
The gameplay derivative is `assets/abandoned_house_playable.glb`. Changes: joined the six wall material surfaces, welded coincident wall vertices, and cut a 1.80 m × 2.24 m entrance opening and widened the kitchen opening to the same clearance. Authored furniture and texture UVs remain. Godot adds static collision to architecture and large furnishings, places the house in the village, adds lighting and story interactions, and reduces normal-map intensity on material overrides. No endorsement by the original author is implied.

Additional CC0 texture sources used for village buildings and generated props:

- https://polyhaven.com/a/worn_mossy_plasterwall
- https://polyhaven.com/a/painted_plaster_wall
- https://polyhaven.com/a/plastered_wall
- https://polyhaven.com/a/plastered_wall_02
- https://polyhaven.com/a/concrete_floor
- https://polyhaven.com/a/weathered_planks
- https://polyhaven.com/a/wood_table_001
- https://polyhaven.com/a/asphalt_06

## Enemy models

**The Frog** (`assets/models/enemy/frog.glb`): generated with Meshy AI from the project's own concept sheet (`Meshy_AI_Character_Frog.glb`, auto-rigged by Meshy). Changes: renamed the 50 bones, scaled to 1.9 m, baked idle / walk / sit animations in Blender (`assets_src/frog/build_frog.py`). Check the Meshy plan used for the download: assets from the free plan are CC BY 4.0 and need attribution to Meshy; paid plans grant their own terms.

**The giant spider** (`assets/models/enemy/spider.glb`): derived from the free "Spider_free" download (unrigged FBX + texture). The original author and license were not recorded when it was downloaded: confirm the source and license before publishing. Changes: scaled by 0.5, rigged with 17 bones and animated by script (`assets_src/spider/build_spider.py`), texture kept, normal map removed.

This document covers the assets touched by this revision; it is not a license audit of the existing character or Backrooms assets.
