# Release verification — 23 November 2026

- Godot 4.7 stable Compatibility, 60 Hz physics.
- Full suite: **127/127 passed**, zero failures; includes complete actual ghost and lethal-key mission routes.
- Editor import and both release exports: exit 0, no ERROR/WARNING matches in logs.
- Windows x86_64 release: embedded game data; headless launch exit 0. GPU movie capture exit 0 on NVIDIA RTX 5070; actual packaged title image inspected (`captures/windows-export00000002.png`).
- Single-threaded web release: served over localhost and run in headless Chrome. Canvas mouse click started the game; Escape paused/resumed; R restarted. Browser page/console error list was empty. Title, paused and resumed images captured and inspected.
- Source GPU captures cover title, help, gameplay, gallery, study, combat, pause and results.
- Input fallback: unavailable native desktop-control pipe prevented OS window-focus automation. Real Godot input-event tests and browser input were used instead. This leaves native OS focus behavior unautomated.
- Original GDD SHA-256 verified unchanged: `D6FC4682A8FBD488E84AEEA431733DFDAD0870D76AB82DFCEEBBA6BBE45062EE`.
- Both build folders include CraftPix/PixelFX licenses, credits, Godot MIT license and Godot third-party notices.

Builds are in `builds/windows` and `builds/web`; source imports from `game/project.godot`. Tests and test room are excluded by export presets. Local captures and builds are intentionally outside source version control.

Fresh whole-project review found input priority, attack-warning geometry, overlapping hit-stop restoration and keyboard focus defects. Each was reproduced by a failing test before fixing; focused suites passed afterward. Both exports were rebuilt after these corrections. No findings were deferred.
