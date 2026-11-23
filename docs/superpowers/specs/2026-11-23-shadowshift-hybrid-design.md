# ShadowShift — top-down stealth and one-hit sword combat

Status: proposed implementation design; awaiting approval.

## Intent and source

Build a complete, playable Godot mission combining ShadowShift's shadow-riding stealth puzzle with responsive, lethal sword combat inspired by Katana ZERO. The user selected the top-down hybrid approach. The source specification is `Shadow_Shift_Game_Design_Document_v0.2.docx` in this project folder. The amendments below are proposed builder decisions, rather than requirements attributed to that document.

The Katana ZERO recovery currently lives at `D:/Game Decompile/Katana`. Use its recovered player/combat functions as behavioral reference, retaining evidence of what was inspected. Native pseudocode has uncertain field names and types; it does not establish exact original GML tuning values. Implement the game in new Godot GDScript, using the supplied asset libraries and custom effects.

## Approaches and selected direction

1. **Top-down hybrid — selected by the user.** Preserve the GDD's authored shadow graph, moving guard anchors, four-area manor and escape puzzle. Add short sword attacks and telegraphed enemy attacks. This preserves the central stealth mechanic while giving the lethal route active combat.
2. **Side-view action adaptation — considered.** Would match Katana ZERO's perspective but require a different map, platforming, patrol logic and shadow routes. The user selected the top-down alternative.

## Deliverable and scope

Create the Godot source project in this existing `Shadow Shifter` folder, alongside the original design document. Deliver one finished 5–10 minute mission, a title/help screen, pause, win/loss results, local best times, sound, effects and a Windows build. Attempt a single-threaded web export as a second deliverable when compatible export templates are available. The project must remain runnable through the installed Godot editor even if an export prerequisite is unavailable.

Use the installed Godot 4.7 with the Compatibility renderer and Godot 4 APIs compatible with the source GDD's 4.6 blueprint. Keyboard and mouse are the initial supported controls. Initial content is Blackglass Manor: courtyard, gate/gallery, lamp alcove and study. Retain the three named patrol guards and Lord Veyr. Add three optional combat sentries as the proposed combat expansion; their placement must leave a viable zero-guard-kill route.

This build is a complete short mission. Campaign progression, extensive inventories, procedural levels and multiple bosses are future scope. Success means both a ghost run and an aggressive run can finish, combat is readable, and restarting never leaves persistent mission state behind.

## Core systems

### Player and controls

Eight-direction movement with mouse-facing attacks. Initial tuning: movement speed 140 px/s, acceleration 1,200 px/s² and deceleration 1,800 px/s². Keep tuning as exported properties or resource data.

- WASD / arrow keys: move in physical form.
- Left mouse button or Space: sword attack in physical form; assassinate the ridden target when hidden in its shadow.
- Hold Shift: show the 96 px reach ring, valid destinations and inactive anchor outlines.
- Shift + left mouse button: merge/shift to a selected reachable shadow. This input takes priority over the sword and never triggers both actions.
- E: emerge when hidden; interact with nearby doors/switches when physical.
- R: instant mission restart. Esc: pause/resume. Context prompts explain the currently valid action.

Player states: PHYSICAL, SHADOW, RIDING and DEAD, with a small combat action state for sword wind-up/active/recovery. Entering a shadow clears active combat hitboxes. Hidden states ignore movement and are never targetable by enemy detection or attacks.

### One-hit combat — amendment to the GDD

Both the player and ordinary enemies die from one valid hit. Lord Veyr also dies from one valid strike. Physical collision alone causes no damage; only active, visible attack hitboxes or projectiles do.

Proposed player sword defaults: 42 px reach, 110° arc, 0.04 s wind-up, 0.10 s active and 0.18 s recovery; 0.12 s input buffer. One swing may hit multiple enemies, but can damage each enemy only once. Walls block attacks. Movement is reduced during a swing but does not become unresponsive. No health bar, damage upgrades or armored multi-hit enemies.

Guard roles use the same patrol/shadow system: blade guards use a telegraphed short lunge; the watchman can fire a telegraphed projectile; the bodyguard uses a longer, slower thrust. Initial melee warning is about 0.45–0.60 s, with a clearly drawn direction and active interval. Bullets collide with walls and doors. All telegraphs and hit windows use the same geometry as their damage checks.

The GDD's 0.3 s spotted meter remains, but filling it **starts combat and the alarm instead of directly killing the player**. Enemies engage while they have line of sight, investigate the last seen position on losing sight, then return to an alert patrol. Hand-authored routes and simple local movement are sufficient; the builder may use navigation if necessary for reliable pursuit. One landed enemy attack causes death. Immediate restart restores the entire mission.

### Shadow shift and riding

Preserve the GDD rules: 96 px range from the physical player or occupied anchor; walls and closed doors block the shift ray. A shift is logically immediate with a 0.15 s cosmetic streak and no cooldown. The player is not exposed during the streak.

Anchors are authored gameplay nodes, independent of cosmetic lighting. Static anchors include well, crate, statue, cupboard and curtain. Moving anchors belong to guards and Veyr. Riding follows the owner's global position each physics frame without reparenting the player. Shift requires an active anchor and an unobstructed source-to-target segment.

Emerge at the anchor or the first safe point on an eight-point, 24 px ring; a blocked search keeps the player hidden and shows why. Owner death or anchor invalidation warns for one second before a safe forced ejection. A riding assassination intentionally emerges at the victim, creates a body and removes that guard's anchor. Other threats can then attack the exposed player.

### Detection, bodies and alarm

Initial vision: 75° cone, 160 px range, wall-clipped rays, 0.3 s suspicion fill and twice-as-fast decay. Detection applies only to physical players. Hidden players may pass through a guard's cone safely. Vision graphics must agree with occlusion checks.

An unobserved body causes no alarm. First discovered body or confirmed player detection starts Veyr's 90 s escape. A second distinct discovered body caps remaining time at 45 s. Count each body once. Veyr follows a deterministic escape path driven by remaining time and reaches its exit exactly when the timer expires; his shadow remains rideable after the lamp puzzle is solved. Alarm cannot silently reset or extend.

## Mission and routes

1. Start in the courtyard well shadow; reach the crate and ride the gatekeeper.
2. The gatekeeper opens the gate for two seconds, carries a rider into the gallery and passes the statue. Killing him drops a key so physical access remains possible.
3. Ride the watchman into the lamp alcove or use its open arch. Emerge at the cupboard, operate the switch and retreat.
4. The one-way lamp switch activates the study curtain and Veyr's anchor. Their inactive outlines are visible before activation.
5. Ride the bodyguard through the study door or open it physically. Reach Veyr and assassinate him. The alarm route allows a late interception before the escape exit.

Every guard death must preserve at least one path to the switch and target. The three extra sentries provide optional sword encounters and cannot act as mandatory moving platforms or key holders. Shadow spacing, patrol waits and room dimensions are implementation choices, constrained by the 96 px range and a demonstrably solvable ghost route. Keep the well/crate tutorial safe from attacks.

Results: Ghost Assassin (no guards killed, no alarm), Silent Blade (guard kills, no alarm), or Messy Success (alarm raised). Failure reports the actual landed attack or Veyr's escape. Display elapsed time, kills, bodies discovered and restart count; persist best time per success rank. Pause freezes AI, projectiles and the escape timer. Restart clears bodies, pickups, keys, doors, suspicion, combat, lighting and the timer while preserving only intended run statistics.

## Art, sound and feel

Use a consistent top-down pixel-art presentation: blue-grey stone/manor surfaces, violet/cyan shadow energy, amber vision and red danger. Proposed internal viewport is 640×360 with nearest-neighbor scaling and a scrolling camera; 32 px gameplay tiles. The builder may adjust viewport size to fit the chosen character art without altering gameplay distances.

Prefer compatible character, dungeon and prop art from `D:/Game Assets/2D Assets`, recording pack paths and licenses. Candidate packs found include the free top-down roguelike game kit and free 2D top-down pixel dungeon pack. Inspect actual sheets before selecting them. Use `D:/PixelLab` or connected pixel generation only for missing cohesive assets. Use `D:/Pixelfx` exports for slashes, shift departure/arrival, impacts and death effects, with frame timing/pivots preserved. Generate small code-native indicators where appropriate.

Include shift and sword sounds, impact/death feedback, alarm cue and a quiet ambient bed. Strong hits get restrained camera shake and roughly 45 ms hit-stop; menus, restart and pause must remain responsive. Keep environmental visibility readable rather than making the entire screen dark. Provide a brief in-game control guide and visible objective progression.

## Architecture and validation

Use separate player, enemy, anchor/shift, door, interactable, combat, alarm, mission, effects and UI responsibilities. Shared enemy data drives the patrol guards and sentries. Use layers/groups consistently and centralize tuning. The original GDD remains unchanged; keep an implementation/change note explaining its combat amendments.

Automated checks should exercise actual game logic: shift distance and occlusion, safe emergence, hidden immunity, one hit per swing/target, one-hit deaths, projectile/wall blocking, unique body discovery, alarm cap, deterministic escape, pause and full reset. Add an integration scenario that completes the ghost route and a lethal route, including killing the gatekeeper and recovering access with his key.

Run Godot's import/parser checks and headless integration tests. Visually inspect the running game, combat effects, readable cones, UI and restart behavior. Verify a Windows export launches; verify web export when templates and a browser are available. Report any export limitation rather than claiming an untested platform works.

## Approval and builder discretion

Approval covers the top-down hybrid, the explicit combat/detection amendments, the six-guard-plus-target mission, source folder and first-build scope above. Exact map construction, guard waypoints, asset selection, tuning adjustments and internal file organization are left to the builder, subject to the acceptance checks. Once approved, write the implementation plan and build the mission.
