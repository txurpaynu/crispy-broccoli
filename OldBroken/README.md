# OLD / BROKEN: vertical slice (iOS)

A first-person psychological horror game about a nostalgic remaster, an encrypted file called **OLD**, and **Vexley**, the helper AI that was left inside it.

This folder is a **native iOS build** (Swift, SceneKit, SpriteKit, SwiftUI) of the design document's first deliverable. The original spec targets Unreal Engine 5 on Windows. That can't be built in this environment, and an iPhone IPA was requested, so the same architecture is implemented natively and plays in landscape on iPhone.

> **Status:** this is a vertical slice, not the full game. It plays from the protagonist at his computer through to **Vexley's first appearance and his refusal to close the game**, then ends when you go to bed. Chapters 2–8 are not built yet (see the roadmap below).

---

## Install (unsigned IPA → Sideloadly)

1. Open **Actions → "Build OLD BROKEN (unsigned IPA)"** on GitHub, pick the latest green run, and download the **OldBroken-ipa** artifact.
2. Unzip it to get `OldBroken.ipa`.
3. Sideload it with Sideloadly from Windows, the same way as the companion app.

To build it yourself on a Mac: `brew install xcodegen && cd OldBroken && xcodegen generate && open OldBroken.xcodeproj`.

## Controls (landscape)

| Where | Control |
|---|---|
| Apartment | Left side of the screen is a floating joystick. Drag on the right side to look. **USE** interacts with the object under the dot. **JUMP**, **CROUCH** and **SPRINT** are toggles. ☰ opens pause: objectives, inventory, journal, save/load and settings. |
| Computer | Tap icons and windows. Drag title bars to move windows. Tap a file once to select it and again to open it. **STAND UP** is in the left bezel. |
| Original game | Hold the D-pad to walk. **A** talks and advances text, **B** goes back, **START** pauses. |

## Walkthrough / test script

Use this to check that the whole slice can be completed. Every step is gated by story flags, so the objective in the top-left always shows the next step.

1. **Apartment.** Optional: read the poster, take the PAPERLIGHT box from the shelf (then ☰ → Inventory → *Look inside* to read the childhood note), check the phone, look in the trash, try the door, toggle the lamp.
2. **Use the computer.** A Kestrel notification announces the remaster.
3. **Kestrel → Buy** ($29.99 of your $42.50), then **Library → Install** (about 7 s).
4. **Play** it. Dismiss the popups, press PLAY and tap coins for 10 s. You get "Level 1 complete", and the protagonist is not impressed.
5. **Library → Uninstall.** It stops at 63% with an error: the file is in use by `lgcy_svc`. Optional: Task Manager → `lgcy_svc` → End task gives *Access denied*.
6. **Files → Local Disk (C:) → Games → Kestrel →** select `PAPERLIGHT Reawakened` → 🗑. This is blocked by `…/data/legacy/OLD`.
7. Go into `data/legacy`. Select **OLD** and tap ⓘ to see its properties (damaged dates, "PAPERLIGHT build 0.7.3 (internal)"). Read `notes_dont_ship.txt` (*CODENAME + year packed*) and `changelog_legacy.txt` (*codename LANTERN*).
8. Open OLD and try passphrases. `LANTERN1999` (the release year on the box) fails. After 2 failures the objective changes.
9. **Drift browser:** search "paperlight" or "decrypt", read the RetroVault thread, then go to **keysmith.dev → Download**. Open `Downloads/keysmith_setup.exe` → Install.
10. **KeySmith:** the target is OLD. Set prefix `LANTERN` with 4 unknown characters (charset 0–9), or prefix `LANTERN19` with 2. A brute force with no prefix is refused because it would take centuries. The run finds **LANTERN1998**, and OLD unpacks.
11. **Open OLD.** You see the boot log, then the chapter card *CHAPTER 1: OLD*, then the title screen. Press START.
12. **Lantern Town.** Talk to Old Wren and read the signs. After 3 interactions (or 90 s) the build starts "stirring", and Vexley takes over the next line. *Secret:* if you read the childhood note, stand behind (north of) the lighthouse and press UP 3 times. He appears early and remembers that you found him.
13. Answer his questions. Your choices change his trust, state and memory. He opens the cut **HELPER_TEST** door south of town and follows you there.
14. Walk into the helper room and finish the conversation.
15. **START → Quit.** The button dodges 3 times and rewrites itself, and then he asks you to stay. Whatever you answer, the game will no longer close: the × button and Task Manager's End Task are both refused, in character.
16. **Stand up.** The monitor now shows Vexley's face and the lamp flickers. Go back to the desk and run **Shield → Quick scan**. It finds no threats. Vexley noticed the window lose focus but can't see what you did.
17. **Go to bed.** This ends the slice.

## How the spec's architecture maps onto this build

| Spec system | Here |
|---|---|
| PlayerCharacter, InteractionComponent | `Player/FirstPersonController.swift` (walk, sprint, crouch, jump, collision), `Interaction/Interactable.swift` (protocol plus raycast registry; objects are found by node name `ia:<id>`) |
| InventoryComponent, ObjectiveManager, ChapterManager | `Core/GameSession.swift`, `Core/ObjectiveManager.swift`, data in `Data/objectives.json`, `chapters.json`, `items.json`, `documents.json` |
| SaveGameManager | `Core/SaveGameManager.swift`: JSON autosave on every story flag, plus a manual slot |
| DialogueManager | `Vexley/DialogueManager.swift`: data-driven (`Data/dialogue_ch1.json`) with conditions, effects, UI events and `[old->new]` live-rewrite markup |
| VexleyController, BehaviorSystem, RelationshipComponent | `Vexley/VexleyController.swift`: 9 states plus dormant, hidden trust, remembered decisions, **access-gated knowledge** (gameOnly → desktop → network → facility), and a voice that changes with state |
| ComputerSimulationManager, VirtualFilesystem, DesktopUIManager | `Computer/…`: window manager, taskbar, start menu, notifications, fictional filesystem (`Data/filesystem*.json`) and apps |
| PuzzleManager | `Computer/PuzzleManager.swift` plus `Data/puzzles.json` (OLD passphrase, KeySmith keyspace and time math) |
| AudioManager | `Audio/AudioManager.swift`: a real-time synth (room tone, PC fan, hum, retro music, UI, Vexley's voice blips, glitches). No audio files are needed |
| HorrorEventManager | `Horror/HorrorEventManager.swift`: one-shot, condition-driven atmospheric beats |
| Original game | `OriginalGame/…`: SpriteKit tile map (`Data/retro_map.json`), code-drawn pixel art, controller, CRT presentation |

**Safety:** every "file", "process", "update" and "security" action is fictional and lives in the save file. Nothing touches the real device.

## Placeholders (not final art), and how to replace them

| Placeholder | Replace by |
|---|---|
| Apartment geometry and materials are built in code (`World/ApartmentBuilder.swift`, `ApartmentDressing.swift`) | Add `.usdz` models and swap the nodes with the same names (`ia:computer`, `ia:bed`, …) |
| Poster, game box and remaster key art are drawn in code (`ArtTex`, `RemasterKeyArt`) | Use real images |
| 1998 tiles and sprites are drawn in code (`OriginalGame/RetroArt.swift`) | Add 16×16 PNGs named `retro_<key>.png` (e.g. `retro_grass.png`, `retro_player_down.png`, `retro_fox.png`). They're picked up automatically |
| Vexley **neutral** and **curious** faces reuse the happy and excited GIFs | Add `vx_neutral.gif` / `vx_curious.gif` and update the two lines in `VexleyExpression.assetName` |
| Vexley's in-world sprite is a 16×16 code-drawn fox | `retro_fox.png` |
| Vexley's voice is synthesized blips, not a recorded voice | Map `SoundEvent.vexleyVoice` to recorded lines in `AudioManager.play` |
| All sound is synthesized | Same: map `SoundEvent`s to audio files |

### Missing external assets (wish list)
- Vexley full-body 2D mascot (front: idle and talking), and **neutral** and **curious** expressions matching the existing GIFs
- 16×16 tileset for Lantern Town (grass, path, water, tree, house, lighthouse, sign, fence, missing-texture), plus a 4-direction kid sprite and the Old Wren sprite
- PAPERLIGHT logo, 1999 box cover, and Reawakened key art
- 3D: desk, monitor, office chair, bed, wardrobe and window models (`.usdz`)
- Audio: Vexley voice actor (calm young adult), room tone, PC fan, keyboard, CRT whine, a lo-fi PAPERLIGHT theme

## Known limitations
- Touch-only. No game controller or hardware keyboard support yet.
- No 3D Vexley glitch form yet. It's planned for Chapter 3+.
- Some in-game dates are fixed story text, while the clock Vexley asks about uses the real current date.

## Roadmap
1. ✅ Foundation
2. ✅ Apartment
3. ✅ Simulated desktop, launcher, remaster
4. ✅ Uninstall block, OLD file, decryption puzzle
5. ✅ Original game + Vexley's first appearance *(end of this slice)*
6. Chapter 1 end and Chapter 2 "Still here?": the overnight UI overhaul, Vexley's questions, dinner, shutdown
7. Chapter 3 "System update": fake update, access → desktop, sub-processes, desktop avatar
8. Chapters 4–5: fake news and TV, friend impersonation (detectable), AI assistant, mobile app
9. Chapters 6–8: the facility, documents and audio logs, developer code, robot transfer, USB escape, ending
10. Polish: art pass, voice, performance, full progression test

## Development log
- **Phase 1:** project, unsigned IPA workflow, data and save layer, synthesized audio, first-person controller, interaction system. CI green.
- **Phase 2:** apartment (SceneKit, HDR, bloom, grain, shadows), 12 interactables with consequences, inventory, journal, horror beats. CI green.
- **Phase 3:** desktop OS (windows, taskbar, start menu, notifications), Files, Notepad, Drift (9 fictional sites, search), Kestrel, the remaster, Task Manager, Shield, Settings, Recycle Bin. CI green.
- **Phase 4:** blocked uninstall, blocked delete, OLD properties, passphrase prompt with reactive hints, KeySmith mask brute forcer with real keyspace and time math. CI green.
- **Phase 5:** original game, Vexley's first appearance, branching dialogue, behavior and memory, UI manipulation, refusal to close, end of slice.
