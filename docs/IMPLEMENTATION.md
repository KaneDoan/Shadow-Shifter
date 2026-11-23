# Implementation notes

The approved hybrid design in `superpowers/specs/2026-11-23-shadowshift-hybrid-design.md` preserves top-down shadow riding and the four-area manor route. Combat replaces the original GDD's immediate detection failure: full suspicion starts enemy engagement and the 90-second escape alarm. A second unique discovered body caps remaining time at 45 seconds without moving Veyr backward.

Six guards and Veyr share one-hit rules. Sword geometry, wall occlusion and per-swing target registration are independent of sprite effects. Hidden/riding players are immune; emergence checks real physics shapes and offers alternate safe positions. Doors remain open while occupied. Guards navigate around walls after investigating an off-route location. Mission reset reloads the scene, while run counts and local best times persist.

The project uses code-authored TileMapLayer geometry, selected CraftPix sheets, exported PixelFX atlases and original synthesized sound. PixelFX pivots and frame rates are retained; cosmetic speed adjustments match combat timing. Pause freezes mission simulation while UI and real-time hit-stop restoration remain responsive.

Tests use real actor and mission entry points, including complete ghost and lethal-key routes. Accelerated route tests reduce waiting; physical walking uses a lower acceleration factor to avoid skipping test waypoints. Captured presentation fixtures are separate from route verification.

Local Qwen handled GDD summarization and bulk native-reference triage. Numeric design claims and relevant native lines were verified directly before use. No paid generation was necessary.
