# ShadowShift credits and asset provenance

## Pixel art

Selected characters and dungeon art by **CraftPix** from the user's local library:

- `D:/Game Assets/2D Assets/CraftPixLibrary/packs/free-top-down-roguelike-game-kit-pixel-art/`
- `D:/Game Assets/2D Assets/CraftPixLibrary/packs/free-2d-top-down-pixel-dungeon-asset-pack/`

Manor art pass (characters and Blackglass Manor visuals), imported by `tools/prepare_manor_art.py`:

- `nobles-manor-pixel-top-down-tileset-asset-pack` — floors, walls, props, fountain, gargoyle
- `free-swordsman-1-3-level-pixel-top-down-sprite-character-pack` — guards (level 3)
- `archer-1-3-level-pixel-top-down-sprite-character` — watchmen (level 2)
- `free-vampire-4-direction-pixel-character-sprite-pack` — Lord Oswald

- `simplified-medieval-gothic-pixel-font-for-video-games` — `Simplified Gothic` display font (menus, headings, speaker names)

Menu, intro-card and dialogue-bar patterns adapted from the user's own Dead Man's Switch project; its Pixolde font is not used here.

The current build no longer uses any art from the two earlier packs above; doors are custom-drawn. Their files remain in `game/assets/` but are unreferenced.

Original bundled license files are retained under `game/assets/licenses/`. They point to [CraftPix file licenses](https://craftpix.net/file-licenses/). `game/assets/manifest.json` records the exact archive member and SHA-256 of each extracted file. The assets are used in the game rather than redistributed as a standalone asset pack.

## Design and code assistance

Original ShadowShift GDD supplied by the user. Hybrid combat amendments approved in `docs/superpowers/specs/2026-11-23-shadowshift-hybrid-design.md`.

Godot code and project assembly assisted by Codex. Local Qwen summarized the GDD and triaged native reference material; important claims were checked directly. Original native Katana ZERO recovery is consulted as a behavioral reference; recovered game artwork and music are not included in this project.

## Engine

Made with [Godot Engine](https://godotengine.org/), MIT license. Engine third-party notices accompany exported builds where required.

## Player character

The assassin (Ruby Azazel) is the user's own character design, generated as pixel art with [PixelLab](https://pixellab.ai) (character `307c6325-822c-4f57-af48-c82906f8aec8`: pro rotations; idle, walk, hurt and death templates; custom dagger-slash animation) and converted to game strips by `tools/import_pixellab_character.py`.

## Pixel effects

Five effect atlases exported from the user's `D:/Pixelfx` checkout (Patch Pixel / pixelfx): sword slash, poof recolored for shifting, bullet impact, shadow flames and torch. Source ids, recolor options and local inspection sheets are recorded in `game/assets/fx/manifest.json`. The MIT license and upstream notices, including Hugo Duprez / Sprite Fusion attribution for adapted effects, are retained in `game/assets/licenses/pixelfx-LICENSE` and `pixelfx-NOTICE.md`. Stock actors are excluded from the exported atlases. Game playback deliberately accelerates some cosmetic effects to match the approved combat timing; gameplay hitboxes remain independent.

## Sound and custom drawing

The nine short sound cues and sixteen-second ambient pad are original deterministic synthesis created for this project with `tools/make_audio.py`. UI, landmark shapes, shadow rings, danger indicators and map composition are custom code-assisted work. No paid pixel-generation service was required for this build.
