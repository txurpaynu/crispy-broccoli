# Shimeji Companion (iPhone)

A shimeji-style fox mascot for iPhone that you can talk to. It reacts to your messages
and to being poked, grabbed and thrown with animated faces (happy, excited, annoyed,
angry, worried, scared, plus a 404 face when its brain errors and a secret glitch face).

Needs iOS 26 (any iPhone that runs it; the AI chat needs Apple Intelligence, e.g. iPhone 15 Pro or newer).

- **On-screen mascot (in the app):** hops along the bottom, clings to the sides, crawls on the ceiling, naps, falls. Drag it to pick it up (scared face), flick it to throw it (angry face), tap it to pet it, tap the floor to call it over.
- **AI chat, no paid API:** uses Apple's on-device model (Foundation Models + Apple Intelligence). Free, offline, private. For every reply the model also picks which face to make. If Apple Intelligence isn't available it falls back to scripted replies with keyword-based faces.
- **Editable personality:** tap the gear icon to change the name and the personality text the AI follows.
- **Boredom notifications:** opt in from the gear screen. When you leave the app, Vexley schedules one playful check-in for two hours later; opening the app cancels it. iOS notification permission is required.
- **App-open reactions:** use the `Tell Vexley About an App` action in a Shortcuts personal automation. Create one automation for each app you want to share (App → Is Opened), add the Shimeji action, enter that app name, and turn off Ask Before Running if you want it automatic. It reacts with a local notification.
- **Safari page sharing:** enable `Tell Vexley About This Page` under Safari → Extensions. On a page, tap the Safari page menu → Extensions → Tell Vexley, then allow site access when prompted. It sends the site’s domain to Vexley as a local notification; it does not watch browsing history.
- **Home Screen widget:** add Vexley from the iPhone widget gallery in small or medium size. Tap it to open chat. It mirrors the latest face, mood, heart meter, and message while the Live Activity is active; otherwise it shows a friendly default state.
- **Lock Screen / Dynamic Island:** "Show on Lock Screen" starts a Live Activity so the companion stays visible with its mood and last message.

## Change the character

| What | Where |
|---|---|
| Default name, personality, idle lines, scripted replies | `ShimejiCompanion/Personality.swift` |
| Animated faces in the app | `ShimejiCompanion/Expressions/*.gif` (square, transparent, keep the file names) |
| Faces on the Lock Screen / Dynamic Island | `CompanionWidget/Assets.xcassets/face-*.imageset` (still PNGs) |
| Which face goes with which event or mood | `ShimejiCompanion/CompanionStore.swift` (`handle`) and `Face.resting` in `Shared/CompanionShared.swift` |
| Movement speeds and behaviour odds | `ShimejiCompanion/ShimejiEngine.swift` |

## Build the IPA (no Mac needed)

Every push to `main` runs `.github/workflows/build-ipa.yml` on a GitHub macOS runner:
XcodeGen generates the project, `xcodebuild` builds with signing turned off, and the
unsigned `ShimejiCompanion.ipa` is uploaded as a workflow artifact.

To get it: open the repo on GitHub → **Actions** → latest **Build unsigned IPA** run →
download **ShimejiCompanion-ipa** at the bottom (it's a .zip with the .ipa inside).
You can also start a build by hand with **Run workflow**.

## Install on your iPhone from Windows (Sideloadly)

1. Install **iTunes** and **iCloud** from apple.com (the website versions, not the Microsoft Store ones).
2. Install **Sideloadly** from sideloadly.io.
3. Plug in your iPhone, unlock it and tap **Trust**.
4. Drag `ShimejiCompanion.ipa` into Sideloadly, type your Apple ID, click **Start**.
5. On the iPhone:
   - Settings → Privacy & Security → **Developer Mode** → on (the phone restarts).
   - Settings → General → VPN & Device Management → tap your Apple ID → **Trust**.
   - Settings → **Apple Intelligence & Siri** → turn on Apple Intelligence (needed once for the AI; you never have to call Siri).
6. Open **Shimeji**. Tap the gear to set the personality and notifications.
7. To add the Home Screen widget, touch and hold the Home Screen, tap **Edit → Add Widget**, search for **Vexley**, choose small or medium, then tap **Add Widget**.

With a free Apple ID the app expires after **7 days**. Re-run Sideloadly to refresh it
(your chat and settings stay). The app plus its Lock Screen widget use 2 of your
free account's app IDs.
