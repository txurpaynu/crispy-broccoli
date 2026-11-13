# Vexley for Meta Quest (mixed reality)

Vexley's animated 2D head bounces around your **real room** on Meta Quest 3 / 3S / Pro / 2.
He uses your Quest's room scan to find the floor, walls, ceiling and furniture, then
hops around, climbs walls, crawls on the ceiling, drops off, leaps onto tables, rolls,
naps, dances and occasionally glitches and teleports. Same personality, moods, happiness,
chat and face animations as the iPhone app.

> Horizon OS does not let any app draw on top of other apps, so Vexley lives in his own
> mixed-reality app (your room shows through around him) rather than over the Quest menu
> or other apps.

## Install (sideload)

1. Turn on **Developer Mode** for your headset in the Meta Horizon phone app
   (Devices → your headset → Headset settings → Developer mode).
2. On a computer, download the APK directly from the **quest-latest** release:
   `https://github.com/txurpaynu/crispy-broccoli/releases/download/quest-latest/vexley-quest.apk`
   (every build also uploads it as the `vexley-quest-apk` artifact on its Actions run).
3. Install it with **SideQuest** (drag the APK onto the window) or **Meta Quest Developer Hub**
   (Device Manager → Apps → Add build), or `adb install -r vexley-quest.apk`.
4. On the headset: Library → filter **Unknown Sources** → **Vexley**.
5. Allow the **spatial data** permission when asked, so he can see your walls. If you've never
   scanned your room, the Quest's room setup opens; without a scan he plays in a pretend
   4 × 4 m room around you.

## Controls (controllers)

| Do this | What happens |
|---|---|
| Squeeze **grip** near him | Grab him; let go while moving to throw him (he bounces, or splats on walls) |
| Brush the controller over him | Pet him |
| Point and pull the **trigger** at a floor, wall, ceiling or table | He leaps there |
| Point and pull the **trigger** at him | Boop (counts as a pet) |
| **A / X** | He comes over to you |
| **B / Y** | Open or close the chat window (point and pull the trigger to tap keys) |
| Left **menu** button | Re-scan your room |

Chat lines like "climb the wall", "dance", "come here", "roll", "jump on the table" or
"nap" also make him do it.

## How it's built

- **Godot 4.4** (`gl_compatibility` renderer) with the
  [Godot OpenXR Vendors plugin](https://github.com/GodotVR/godot_openxr_vendors) for Meta
  passthrough and the Scene API (room scan anchors). Both are downloaded by CI, not committed.
- `scripts/room.gd`: turns scan anchors into flat surfaces (pretend room fallback).
- `scripts/vexley.gd`: the bouncing head and all of his shimeji behaviours.
- `scripts/companion.gd` + `scripts/personality.gd`: mood, happiness, chat history and the
  scripted brain, ported from the iPhone app. Saved to the app's own storage.
- `scripts/chat_panel.gd`: the floating chat window with an on-screen keyboard.
- `art/faces/*.png`: sprite sheets made from the iPhone app's expression GIFs.
- `android-debug.keystore`: a throwaway debug signing key (password `android`), committed so
  every build has the same signature and installs as an update without losing his memory.

The workflow `.github/workflows/build-quest-apk.yml` imports the project, runs a 70-second
headless smoke test of every behaviour, exports a debug APK and checks its manifest.

To open it in the Godot editor: install Godot 4.4.1, download `godotopenxrvendorsaddon.zip`
from the vendors plugin's 3.1.2 release, copy its `addons/godotopenxrvendors` folder into
`quest/addons/`, then use Project → Install Android Build Template.
