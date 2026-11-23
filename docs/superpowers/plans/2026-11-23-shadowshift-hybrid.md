# ShadowShift Hybrid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a playable top-down Godot manor mission with shadow riding, one-hit sword combat, readable stealth, fast resets and tested exports.

**Architecture:** A Godot 4.7 project in `game/`, with small scripts for actors, authored map, shadow validation, combat, alarm/run state, presentation and UI. Pure geometry/alarm models are shared by real gameplay and headless tests; integration tests exercise the actual scene, physics and mission route. Work directly in this new dedicated project folder on `build/shadowshift`; no existing source repository or branch is being modified.

**Tech Stack:** Godot 4.7 Compatibility/GDScript, local CraftPix pixel-art sheets, PixelFX exported atlases, Python asset preparation, procedural WAV audio, Git.

**Spec:** `docs/superpowers/specs/2026-11-23-shadowshift-hybrid-design.md` (approved by the user).

## Global Constraints

- Source location: `D:/Game Project/Shadow Shifter/game`; original Word GDD remains unchanged.
- One complete 5–10 minute Blackglass Manor mission; three named patrol guards, three optional sentries and Lord Veyr.
- One valid hit kills a physical player, ordinary guard or Veyr.
- Shift range 96 px; walls/closed doors block; zero cooldown; cosmetic streak 0.15 s.
- Hidden/riding states cannot be detected or hit; eight emergence samples at radius 24 px.
- Initial vision 75°/160 px; suspicion fills in 0.3 s; full suspicion starts combat/alarm.
- Escape starts at 90 s; a second unique discovered body caps remaining time at 45 s without moving Veyr backward.
- Pixel assets nearest-filtered, 32 px gameplay tiles, initial 640×360 viewport.
- Track source/license and AI assistance in `CREDITS.md`; asset generation occurs only where needed.
- Windows export must be launch-tested. Web export is single-threaded and reported separately if unavailable.

## Review Focus

- Shift-click while a sword input is also held: only shifting occurs; no residual attack after emergence. Task 2/3 integration test.
- Door timer expires while an actor occupies the doorway: the door stays open until clear. Task 2 physics test.
- A ridden enemy dies or an anchor deactivates while emergence is blocked: warning/ejection remains safe and does not strand the run. Task 2/3 test.
- Alarm cap arrives late or the same body is discovered twice: no timer extension, duplicate count or backward boss movement. Task 4 model test.
- Restart/pause during an attack, projectile, hit-stop or alarm: complete reset/freeze and responsive UI. Task 5 integration test.

## Files and interfaces

- `game/project.godot`, `game/main.tscn`: engine settings, input actions, entry scene and RunStats autoload.
- `game/core/rules.gd`: `can_shift(source: Vector2, target: Vector2, active: bool, blocked: bool, reach: float = 96.0) -> bool`, `in_cone(origin: Vector2, forward: Vector2, point: Vector2, reach: float, angle: float) -> bool`, `emergence_candidates(origin: Vector2, radius: float = 24.0) -> Array[Vector2]`.
- `game/core/alarm_state.gd`: `start()`, `discover_body(body_id: int) -> bool`, `tick(delta: float)`, `reset()`; public `active`, `remaining`, `progress`, `bodies_found`.
- `game/core/run_stats.gd`: restart count, ranks, local best times and isolated test save path.
- `game/world/level_data.gd`, `manor_level.gd`: authored wall/floor rectangles, anchors, patrol points, doors, props, switch and boss route. `build(mission: Node)` and `line_clear(a: Vector2, b: Vector2) -> bool`.
- `game/world/shadow_anchor.gd`: `active`, `owner_actor`, `anchor_id`, invalidation signal, readable draw state.
- `game/world/door.gd`: `open_for(seconds: float)`, `try_interact(player: Node) -> bool`, safe deferred closing.
- `game/actors/player.gd`: CharacterBody2D state, movement, input, `request_shift(anchor: Node) -> bool`, `emerge() -> bool`, `request_attack()`, `take_hit(source: Node)`, `is_hidden() -> bool`.
- `game/actors/enemy.gd`: deterministic patrol, suspicion, engagement, telegraph, attack, body and moving anchor; `take_hit(source: Node)`, `is_alive() -> bool`.
- `game/actors/projectile.gd`: swept hit checks against walls and exposed player.
- `game/actors/actor_visual.gd`: directional sheet animation and silhouettes, independent of combat state.
- `game/systems/shadow_system.gd`: anchor registry, reachability, physics ray/shape checks and emergence.
- `game/systems/combat_system.gd`: `resolve_swing(source: Node, origin: Vector2, direction: Vector2, reach: float, arc: float, hit_ids: Dictionary) -> int`; one target hit per swing, occlusion, feedback.
- `game/systems/mission.gd`: root mission lifecycle, map/actors, switch/key, body detection, escape, win/fail/reset; exposes named anchors/enemies for integration scenarios.
- `game/presentation/fx_manager.gd`, `audio_manager.gd`: atlas playback, time-limited feedback and sound.
- `game/ui/game_ui.gd`: title, controls, objectives, context prompt, alert HUD, pause and results.
- `game/tests/test_runner.gd`: headless behavior and scene integration runner (`--suite=rules|shadow|combat|mission|presentation|all`).
- `tools/prepare_assets.py`, `tools/export_fx.mjs`: selected asset extraction, provenance, audio and PixelFX exports; no bulk import of the entire libraries.
- `game/export_presets.cfg`, `README.md`, `CREDITS.md`, `docs/IMPLEMENTATION.md`, `docs/REFERENCE_NOTES.md`: build instructions, deliverables, credits, GDD amendments and verified native reference notes.

## Task 1: Project, assets and shared geometry

**Files:** Create project/entry configuration, `core/rules.gd`, test runner skeleton, `tools/prepare_assets.py`, initial credits and selected character/floor/prop assets.

**Interfaces:** Produces Rules methods above, a runnable project and extracted 32 px directional character sheets for later actors. Tests instantiate scripts dynamically so a missing production module reports a controlled failure.

- [ ] Write rules tests before implementation: shift succeeds at 96 px, fails beyond 96 px, fails inactive/occluded; vision cone includes forward and rejects behind/out-of-range; emergence returns center plus eight unique 24 px samples.
- [ ] Run `Godot --headless --path game --script tests/test_runner.gd -- --suite=rules`; expect explicit FAIL for missing Rules.
- [ ] Implement Rules and minimal project configuration; extract only selected licensed pixel sheets and record sources. Verify sizes/frame counts.
- [ ] Run the rules suite; expect all assertions PASS and exit 0. Run editor import/parser check.
- [ ] Commit task and ledger its verification.

## Task 2: Movement, anchors, riding, emergence and doors

**Files:** Create player, actor visual, anchor, shadow system, door, test-room fixture and minimal mission entry.

**Interfaces:** Consumes Rules. Produces Player/ShadowSystem/Door methods above and physics layer conventions: walls 1, player 2, NPCs 4, anchors 8, interactables 16. Later mission/combat code uses these actor APIs and groups.

- [ ] Add failing physics tests: a wall/closed door blocks a shift, open door allows it; moving an owner carries a rider; hidden player is non-targetable; blocked emergence remains hidden; alternate safe emergence succeeds; occupied doorway prevents closing; Shift+click clears/does not queue attack.
- [ ] Run shadow suite; expect assertions fail on missing behavior.
- [ ] Implement acceleration/movement, state transitions, priority inputs, authored/owned anchors, range highlight, 0.15 s shift visual, safe emerge query and one-second forced-eject warning.
- [ ] Implement timed guard opening/key interaction and safe doorway closing. Add a small playable test room using the actual scripts.
- [ ] Run rules + shadow suites and the test room; expect all checks PASS and no parser/runtime errors.
- [ ] Commit task and ledger verification.

## Task 3: One-hit sword combat and enemy attacks

**Files:** Create combat system, enemy and projectile; extend player/visual and combat tests.

**Interfaces:** Consumes actor/shadow methods. Produces guard death/body signal, exposed-player death signal, `resolve_swing(...)`, active-attack geometry and projectile collision used by mission/presentation.

- [ ] Add failing tests: sword inside active arc kills once, outside arc/reach or behind a wall does not; repeated active frames cannot hit a target twice; one enemy hit kills the player; hidden player ignores damage; projectile hits wall before player; killing a ridden guard removes its anchor and safely exposes the rider.
- [ ] Run combat suite; expect FAIL for missing behavior.
- [ ] Implement buffered sword (0.04/0.10/0.18 s), reduced movement during attack, single-hit registry and wall occlusion. Preserve Shift input priority.
- [ ] Implement deterministic patrols, 75°/160 px suspicion, 0.3 s detection, visible blade/thrust/shot wind-up, active attacks and last-seen investigation. Ordinary body contact causes no damage.
- [ ] Run combat plus prior suites; expect PASS, including alive/dead signals firing once.
- [ ] Commit task and ledger verification.

## Task 4: Manor, alarm, boss and complete routes

**Files:** Create level data/manor builder, alarm model, run stats, full mission and scenario tests.

**Interfaces:** Consumes actor/shadow/combat APIs. Produces `Mission` with named courtyard/gallery/alcove/study anchors, patrol guards/sentries, lamp switch, gate-key route, escape path and result stats.

- [ ] Add failing alarm tests: unseen body does nothing; first discovery starts 90 s; duplicate discovery has no effect; second unique body caps at 45 s without extending a shorter timer; boss progress is monotonic and reaches 1 at zero remaining. Reset clears all fields.
- [ ] Add failing scenario tests for a ghost completion and a lethal gatekeeper-key completion using actual shift/interact/kill entry points; assert no mandatory path is lost when any named guard dies.
- [ ] Implement alarm model, body discovery, one-way switch activation, deterministic escape sampling, key fallback, safe intro anchors, four authored areas, three optional sentries and success ranks.
- [ ] Implement complete scene reset and persisted best times, with test save paths isolated from actual player progress.
- [ ] Run mission and all prior suites; expect both routes finish, all reset assertions PASS, no runtime errors.
- [ ] Commit task and ledger verification.

## Task 5: Presentation, audio, UI and playtest polish

**Files:** Complete art/prop layers, FX/audio managers, UI, effects export tooling, credits and presentation tests.

**Interfaces:** Consumes mission state/signals. Produces title/help/pause/results, readable status and objective HUD, directional actors, slashes/shift/death atlases, sound and responsive hit-stop.

- [ ] Add failing integration tests for pause freezing projectiles/AI/alarm, restart during an attack/alarm restoring mission state, and hit-stop completing without freezing UI/restart.
- [ ] Run presentation suite; expect missing/failing pause/reset behavior.
- [ ] Export existing PixelFX candidates, inspect the contact sheets, select cohesive effects and preserve their timing/pivots. Use local assets or generate missing art only as necessary. Generate original short audio cues/ambient bed if suitable licensed audio is unavailable.
- [ ] Implement readable ray-clipped cones, inactive/reachable anchor states, sword/attack warnings, contextual controls, title/help, pause, failure cause and ranked results. Add restrained shake/hit-stop with pause-safe timing.
- [ ] Run all suites. Capture and inspect actual gameplay/menu/results screenshots, and manually exercise movement, shift, riding, slash, interaction, restart and pause. Correct visual/readability defects.
- [ ] Commit task and ledger verification.

## Task 6: Exports, full review and delivery

**Files:** Create export presets, Windows/web artifacts, README, implementation and reference notes. Keep builds outside imported game resources.

**Interfaces:** Consumes the finished project. Produces playable Windows build, optional verified single-threaded web build, source entry points, credits, test evidence and known limitations.

- [ ] Run full import/parser and all behavior/scenario tests; require exit 0 and no script errors.
- [ ] Export Windows with installed 4.7 templates; launch-test the executable. Export web single-threaded, serve locally and browser-test when supported. Report platform-specific blockers accurately.
- [ ] Dispatch one fresh whole-project reviewer against this plan, approved spec, source, tests and ledger. Fix important defects with reproducing RED→GREEN tests, then run the full suite once.
- [ ] Verify final project/build paths, screenshots, licenses and original GDD hash. Complete README with exact controls, launch instructions, verified platforms and limitations.
- [ ] Commit the completed source and record test/export results. Leave the project available in the approved location; no remote publication or upload is part of this task.

## Self-review

All approved spec sections map to the six tasks. Actor/anchor/combat API names are consistent across dependencies. Review Focus cases are assigned to their owning tests. Pure core tests cover boundaries; integration tests cover real physics, mission routes and reset/pause behavior. Export checks are separate from headless tests and must not be inferred from parser success.
