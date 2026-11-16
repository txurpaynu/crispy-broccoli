# TXAWPAY

*Your world, in one place.*

A personal life companion for iPhone: journal, travel, creative projects, learning,
people, health and memories, all stored on your phone first. Built with SwiftUI and
SwiftData for iOS 17 and later. No account is needed.

> **Build status.** This project was written on Linux, where Apple's compiler isn't
> available. Every Swift file passed a syntax check, and the Xcode project file and
> plists were validated, but **the app has not been compiled or run yet.** The first
> build in Xcode (or the included GitHub Actions workflow) is the real test. If it
> reports errors, they will most likely be small type-checking issues; send the
> error list back and they can be fixed quickly.

## Contents

| Path | What it is |
| --- | --- |
| `TXAWPAY.xcodeproj` | Xcode project (needs **Xcode 16 or later**). New files in `TXAWPAY/` are picked up automatically. |
| `TXAWPAY/` | App source: `App`, `DesignSystem`, `Models`, `Persistence`, `Backup`, `Services`, `Features`, `Resources` |
| `TXAWPAYTests/` | Unit tests for the backup format, ZIP, encryption and date maths |
| `Config/Info.plist` | Permissions text, iCloud Drive folder, file type for encrypted backups |
| `Config/TXAWPAY.entitlements` | iCloud (Drive + CloudKit) and push, for a **paid** developer account |
| `Config/TXAWPAY-NoiCloud.entitlements` | Empty entitlements for a **free** Apple ID |
| `.github/workflows/ios-build.yml` | Builds on a Mac in GitHub, runs the tests and produces an unsigned IPA |
| `project.yml` | Optional XcodeGen spec, if you prefer to regenerate the project |
| `scripts/generate_xcodeproj.py` | Script that wrote the Xcode project |
| `design/` | The app icon at full size |

## Building on a Mac

1. Install Xcode 16 or later from the App Store.
2. Open `TXAWPAY.xcodeproj`.
3. Select the **TXAWPAY** target, then **Signing & Capabilities**.
4. Under **Team**, choose your Apple ID (add it in Xcode › Settings › Accounts if needed).
5. Follow either A or B below, then pick your iPhone or a simulator and press **Run** (⌘R).
6. On the phone, the first time: Settings › General › VPN & Device Management › trust your developer certificate. On iOS 16+, also turn on Settings › Privacy & Security › Developer Mode.

### A. Paid Apple Developer account (iCloud works)

1. Keep the bundle ID `com.txawpay.app`. If Xcode says it's taken, change it (for example to `com.yourname.txawpay`) and replace `iCloud.com.txawpay.app` with `iCloud.com.yourname.txawpay` in three places: `Config/TXAWPAY.entitlements` (twice), `Config/Info.plist` (`NSUbiquitousContainers`), and the constant in `TXAWPAY/Backup/BackupDestination.swift` and `TXAWPAY/Persistence/PersistenceController.swift`.
2. In **Signing & Capabilities**, check that **iCloud** shows *iCloud Documents* and *CloudKit* ticked with the container `iCloud.com.txawpay.app`. If the container is red, press the refresh button or **+** to create it.
3. Check that **Push Notifications** is present (CloudKit sync uses silent pushes) and **Background Modes › Remote notifications** is ticked.

### B. Free Apple ID (no iCloud)

Free accounts can't use iCloud capabilities, so signing fails with the full entitlements.

1. In **Build Settings**, search for *Code Signing Entitlements* and change it to `Config/TXAWPAY-NoiCloud.entitlements`.
2. Change the bundle ID to something unique, such as `com.yourname.txawpay`.
3. Apps signed with a free account expire after 7 days; just press Run again to renew.

Everything works except the *iCloud Drive* backup destination and *CloudKit sync*, which
show an honest "iCloud isn't available" message. You can still back up to iCloud Drive by
choosing **Backup › Destination › A folder you choose** and picking a folder inside
iCloud Drive in the Files picker.

## Getting an IPA

* **From GitHub:** push this folder to a GitHub repository. The *iOS build* workflow runs
  on a Mac, runs the tests and uploads `TXAWPAY-unsigned.ipa` as a build artifact. An
  unsigned IPA can't be installed as-is; re-sign it with a sideloading tool such as
  AltStore or Sideloadly (these sign it with your own Apple ID), or with your own
  certificate.
* **From Xcode (signed):** Product › Archive, then Distribute App › *Release Testing*
  or *Debugging* (ad-hoc, paid account) or *App Store Connect* (TestFlight).

## Permissions the app asks for

| Permission | When it's asked | Why |
| --- | --- | --- |
| Photos | Adding photos or videos | Attach media to entries, memories, trips and projects. The system picker is used, so the app only sees what you pick. |
| Location (when in use) | Only when you tap "Use current location" | Tag an entry or a place. Never tracked in the background. |
| Face ID | Turning on App Lock | Lock the app. Falls back to your passcode. |
| Notifications | Turning on any reminder | Journal, water, tasks, birthdays, events, study and workout reminders. All scheduled on the phone. |
| iCloud | Choosing iCloud Drive or CloudKit sync | Optional. Nothing leaves the phone otherwise. |

## Journal backup: how it works

Every journal change is written as a Markdown file, one file per day:

```
TXAWPAY/
  Journal Backups/
    2026/
      November/
        2026-11-16.md
    Version History/      earlier copies of a day file
    Media/                photos and files, if "Include media" is on
    manifest.json         checksums and status for each day
  README.txt
```

**When it writes.** About 2 seconds after you stop typing, when you leave the editor,
when the app goes to the background, at launch if anything is still waiting, and when
the network comes back. Writes are atomic (a half-written file never replaces a good
one), each file is read back and its SHA-256 checked, and failed writes retry with
increasing delays.

**Destinations.**

* **On this iPhone** – the app's own folder, visible in the Files app under
  *On My iPhone › TXAWPAY*.
* **iCloud Drive** – a *TXAWPAY* folder in iCloud Drive (visible in Files and on a Mac).
  The status only says *Backup completed* once iOS reports the file is uploaded;
  until then it says *Waiting for iCloud synchronization*.
* **A folder you choose** – any folder in the Files app, including iCloud Drive,
  a USB drive or a cloud provider. The app keeps access to it with a secure bookmark.

**Statuses** are shown per day and overall: *Saved locally*, *Waiting for iCloud
synchronization*, *Backup completed*, *Backup failed* (with the reason; **Back up now** retries).

**Version history.** Before a day file is overwritten, a copy is kept if the file was
changed outside the app, if an entry was removed, or every 15 minutes while you edit.
Up to 30 copies are kept per day. To see them, open **Profile › Journal Backup**
and tap a day in the list.

**Restoring.** **Profile › Restore Journal** reads a backup folder, `.md`/`.txt` files,
a ZIP, or an encrypted `.txawpaybackup`. It shows a preview marking each entry as new,
newer than yours, or already present, and imports only what you select. Entries are
matched by their id (or by a fingerprint for plain Markdown files), so restoring twice
never creates duplicates.

**Exports.** **Profile › Export & Delete Data** makes a ZIP of the journal (with or without
media) or of everything in the app. Either can be encrypted with a password
(AES-256-GCM, key from PBKDF2-SHA256 with 310,000 rounds). Without the password the
file cannot be opened, by anyone.

## Known limitations

* Encryption applies to exports; the automatic day files are plain Markdown so you can
  read them anywhere.
* Encrypting loads the whole export into memory, and ZIP files are limited to 4 GB.
* Map search and place names need a network connection.
* No home-screen widget yet.
* Demo mode adds sample items labelled "DEMO ·" and removes them in one step; sample
  items are never backed up or exported.
