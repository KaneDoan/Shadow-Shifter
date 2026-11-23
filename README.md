# ShadowShift

A complete, replayable top-down stealth and one-hit sword mission in Blackglass Manor. Ride guards' shadows, extinguish the study lamp, reach Lord Veyr and escape. Detection starts combat and a timed escape alarm.

## Play

Windows: open `builds/windows/ShadowShift.exe`. The executable includes the game data. No Godot installation is needed.

Web: run `python -m http.server 8765 --directory builds/web` from this folder and visit `http://localhost:8765`. Serve the files over HTTP; opening index.html directly will not work. The single-threaded build does not require cross-origin isolation headers.

Source: import `game/project.godot` in Godot 4.7, then press F6 on main.tscn or F5.

## Controls

| Input | Action |
|---|---|
| WASD / arrows | Move while physical |
| Mouse | Aim |
| Shift + left click | Travel to a reachable shadow within the violet range ring |
| E | Emerge, interact with the lamp or unlock the gate with its key |
| Left click / Space | Sword strike; assassinate a ridden enemy |
| R | Restart immediately |
| Esc | Pause / resume |
| F1 | Controls and rules |
| M | Mute / unmute |

Purple rings are shadows; dim rings are inactive. Walls and closed doors block shifts. Hidden riders are safe. Exposed characters die from one valid hit. Watch enemy wind-ups, emerge behind them and strike. The gatekeeper carries a key if you choose a lethal approach. Dead route carriers have alternate walking paths. Ranked results distinguish Ghost, Silent Blade and Messy Success; best times save locally.

## Verify and rebuild

From this folder, using the installed engine:

```powershell
& D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path game --script tests/test_runner.gd -- --suite=all
& D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path game --export-release 'Windows Desktop'
& D:/Godot/Godot_v4.7-stable_win64_console.exe --headless --path game --export-release Web
```

The 127 checks exercise geometry, real physics, riding/emergence, combat, alarm, complete ghost/key routes, reset, pause, hit-stop, keyboard/mouse delivery and guard navigation. Test saves are isolated from player progress.

Windows release was launch-tested and rendered on the local NVIDIA GPU. Web release was tested in headless Chrome with actual canvas mouse/keyboard events. Captures are in `captures/`. The unavailable native desktop-control pipe prevented automated testing of OS window focus; engine input and browser input were tested instead. Mobile/touch and gamepads are outside this prototype's scope.

See `CREDITS.md` for assets and licenses, `docs/IMPLEMENTATION.md` for design decisions and `docs/REFERENCE_NOTES.md` for the decompiled reference limits. Original Word design document is preserved. Builds are local; nothing has been published remotely.
