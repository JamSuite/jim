```
Description: This howto from a tauri project demonstrates a complex matrices of options that are linked together. 
  it was built in close collaboration with Claude Code and is an example where a generic "howto" template will be challenging
  to fit
```

# How to Build and Run Tauri App

## Use case matrix

| Use Case | Host | Target | Script |
|:---|:---|:---|:---|
| [Desktop live dev](#running-in-development) | Mac / Win / Linux | Desktop (local display) | `scripts/tauri-dev.sh` |
| [Desktop distribution build](#building-for-local-testing) | Mac / Win / Linux | `.app` / `.msi` / `.AppImage` | `scripts/tauri-build.sh` |
| [iOS simulator live dev](#ios-simulator) | Mac | iOS Simulator | `scripts/ios-dev.sh` |
| [iOS connected device live dev](#ios-device) | Mac | Physical iOS device | `scripts/ios-dev.sh --device` |
| [iOS sideload build](#ios-sideload) | Mac | `.ipa` | `scripts/ios-build.sh` |
| [Android emulator live dev](#android-emulator) | Mac / Win / Linux | Android Emulator | `scripts/android-dev.sh` |
| [Android connected device live dev](#android-device) | Mac / Win / Linux | Physical Android device | `scripts/android-dev.sh --device` |
| [Android APK sideload build](#android-apk-sideload) | Mac / Win / Linux | `.apk` | `scripts/android-build.sh` |

---

## Data locations

After you run any of the scripts above, two on-disk artifacts matter: the SQLite database (`app.db`) and any source files the user has attached to a topic. Both are governed by the bundle identifier `app.mycompany.client` (set in `packages/rust/tauri.conf.json`); the runtime resolves the data directory at boot via `app.path().app_data_dir()` in `packages/rust/src/lib.rs`.

| Use Case | `app.db` path | Attached source files |
|:---|:---|:---|
| Desktop dev (macOS) | `~/Library/Application Support/app.mycompany.client/app.db` | (planned) `app_data_dir/sources/<sha256>` if copied; otherwise referenced in place by absolute path |
| Desktop dev (Windows) | `%APPDATA%\app.mycompany.client\app.db` | same |
| Desktop dev (Linux / WSL host) | `~/.local/share/app.mycompany.client/app.db` (or `$XDG_DATA_HOME/app.mycompany.client/`) | same |
| Desktop build (`.app` / `.msi` / `.AppImage`) | same as the dev row for the same host — bundle identifier is shared | same |
| iOS simulator | `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<APP-UUID>/Library/Application Support/app.mycompany.client/app.db` | not copied — security-scoped bookmark blob lives in the `sources` row; bytes stay in the Files provider (iCloud Drive / On My iPad / Obsidian Sync / etc.) |
| iOS device | inside the app sandbox at `Library/Application Support/app.mycompany.client/app.db`. Pull via Xcode → **Window → Devices and Simulators** → app → **Download Container** | same |
| iOS sideload (`.ipa`) | same as iOS device | same |
| Android emulator | `/data/data/app.mycompany.client/files/app.db` (debug builds: `adb shell run-as app.mycompany.client cat files/app.db`) | not copied — persistable `content://` URI lives in the `sources` row; bytes managed by the SAF-providing app |
| Android device | same | same |
| Android sideload (`.apk`) | same | same |

**Dev and prod share the same path.** `tauri-dev.sh` and `tauri-build.sh` produce binaries with the same bundle identifier, so the dev binary reads and writes the *same* `app.db` as the installed prod build on the same machine. Delete the file (and the `-wal` / `-shm` sidecars) if you want a fresh DB. `cargo clean` and `scripts/clean.sh` do **not** touch it.

**Mobile never copies bytes.** On iOS and Android, "attaching a source" stores an opaque OS-managed handle (a security-scoped bookmark blob on iOS, a persistable `content://` URI on Android) in the `sources` row. The original file stays where the user put it. This is intentional — mobile sandboxes are storage-pressured, and the user's source-of-truth (their Obsidian vault in iCloud / Drive / wherever) remains the canonical copy. See [`docs/brainstorms/20260506-svelte-tauri-files-access.md`](brainstorms/20260506-svelte-tauri-files-access.md) for the design rationale.

**Backups live next to the DB.** Pre-migration `VACUUM INTO` snapshots are written to the same `app_data_dir` per the recovery flow described in [`HOWTO_MIGRATIONS.md`](HOWTO_MIGRATIONS.md#how-to-rollback). The `restore_from_backup` command validates that any restore path is canonicalized inside `app_data_dir` before touching anything.

---

## Dev environment setup

### WSL (devcontainer)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) with the WSL2 backend enabled.
2. Install [VS Code](https://code.visualstudio.com/) and the **Dev Containers** extension.
3. Clone the repo and open it in VS Code.
4. Command Palette → **Dev Containers: Reopen in Container**.
   The container installs all dependencies automatically via `postCreate.sh`.
5. Open a terminal inside the container. The environment is already set up.
   To re-run manually:
   ```sh
   source scripts/setenv
   ```

### Mac

1. Install [Rust](https://rustup.rs/) (stable toolchain).
2. Install [Bun](https://bun.sh/).
3. Install [Xcode](https://developer.apple.com/xcode/) (required for iOS targets).
4. Clone the repo and run:
   ```sh
   source scripts/setenv
   bun-install.sh
   ```

---

## Running in development

[⬑ Back to top](#use-case-matrix)

### Desktop (WSL host)

Run from your WSL terminal **outside the devcontainer** (the devcontainer has no display):

```sh
source scripts/setenv
scripts/tauri-dev.sh
```

### Desktop (Mac)

```sh
source scripts/setenv
scripts/tauri-dev.sh
```

### iOS simulator

```sh
source scripts/setenv
scripts/ios-dev.sh
```

Requires macOS and `packages/rust/gen/apple/` to exist. See [Mobile scaffolding](#mobile-scaffolding-first-time-setup).

### iOS device

Set your Apple team ID before running (find it at developer.apple.com/account → Membership):

```sh
export TAURI_APPLE_DEVELOPMENT_TEAM=XXXXXXXXXX   # your 10-character team ID
source scripts/setenv
scripts/ios-dev.sh --device
```

A free Apple ID works for personal on-device development (certificate expires after 7 days; re-run to renew). A paid Apple Developer account ($99/year) removes the expiry limit.

### Android emulator

Requires an AVD (Android Virtual Device). Create one in Android Studio (Tools → Device Manager) or via `avdmanager` CLI. Start the emulator before running — Tauri will prompt you to select it.

```sh
source scripts/setenv
scripts/android-dev.sh
```

Requires `packages/rust/gen/android/` to exist. See [Mobile scaffolding](#mobile-scaffolding-first-time-setup).

### Android device

Enable USB debugging on the device (Settings → About → tap Build Number 7 times → Developer Options → USB Debugging), then connect via USB:

```sh
adb devices   # verify your device appears
source scripts/setenv
scripts/android-dev.sh --device
```

---

## Building for local testing

[⬑ Back to top](#use-case-matrix)

Each build runs on its native host OS — `tauri-build.sh` produces a macOS `.app` on Mac, a Windows `.msi` on Windows, and a Linux `.AppImage` on Linux. Cross-compilation is not supported. The script prints a preamble showing the target and what systems the artifact will run on. For a Linux build, run from the host for a host-portable AppImage, or from the devcontainer to produce one linked against the container's Debian libraries.

### macOS

```sh
source scripts/setenv
scripts/tauri-build.sh
# Output: target/release/bundle/macos/Myapp.app
```

Share the `.app` by zipping it. Recipients on other Macs will see a Gatekeeper warning on first open — bypass with right-click → Open → Open (once per machine).

### Windows

Build from a Windows host (not the devcontainer):

```sh
source scripts/setenv
scripts/tauri-build.sh
# Output: target/release/bundle/msi/Myapp_*.msi
```

Unsigned builds trigger a SmartScreen warning ("Windows protected your PC"). Bypass: click "More info" → "Run anyway".

### Linux

Run from the WSL host or any Linux machine for a host-portable build. Building inside the devcontainer also works but produces a `.AppImage` linked against the container's Debian libraries — the script will print a notice when this happens.

```sh
source scripts/setenv
scripts/tauri-build.sh
# Output: target/release/bundle/appimage/Myapp_*.AppImage
```

The `.AppImage` is self-contained — no install required. Share the file directly. Recipient: `chmod +x Myapp_*.AppImage && ./Myapp_*.AppImage`

### iOS (sideload)

Requires a paid Apple Developer account ($99/year), an ad-hoc provisioning profile, and each tester's device UDID registered in your Apple Developer portal.

```sh
export TAURI_APPLE_DEVELOPMENT_TEAM=XXXXXXXXXX
source scripts/setenv
scripts/ios-build.sh
# Output: packages/rust/gen/apple/build/arm64/Myapp.ipa
```

Install the IPA on a connected device (iOS 17+):

```sh
xcrun devicectl list devices                  # find the device UDID
xcrun devicectl device install app \
  --device-id <device-UDID> \
  packages/rust/gen/apple/build/arm64/Myapp.ipa
```

Alternatively: Xcode → Window → Devices and Simulators → select device → drag-drop `.ipa` onto the Installed Apps list.

#### Remote testers

**Step 1 — collect the tester's UDID**

Ask the tester to open `https://get.udid.io` in Safari on their iPhone. They tap "Get UDID", install a temporary config profile (Settings → General → VPN & Device Management), and their UDID is displayed. No Mac or Xcode needed on their end.

Register the UDID in your Apple Developer portal (Certificates, IDs & Profiles → Devices → +), regenerate the ad-hoc provisioning profile, and rebuild with `ios-build.sh`.

**Step 2 — distribute the IPA**

Option A — Diawi (1–10 testers, simplest):

1. Upload the signed `.ipa` to `https://www.diawi.com`
2. Share the generated link with the tester
3. Tester opens the link in Safari on device → tap Install

Option B — TestFlight (ongoing beta, any number of testers):

- Requires App Store Connect; tester installs the free TestFlight app
- No UDID registration needed — TestFlight handles device authorization
- Internal testers (App Store Connect members): immediate access, no App Review required
- External testers: first build requires Apple App Review; subsequent builds auto-approved

### Android (APK sideload)

The debug APK is automatically signed with the Gradle debug keystore — no signing setup needed.

```sh
source scripts/setenv
scripts/android-build.sh
# Output: packages/rust/gen/android/app/build/outputs/apk/universal/debug/app-universal-debug.apk
```

Install on a connected device:

```sh
adb install -r packages/rust/gen/android/app/build/outputs/apk/universal/debug/app-universal-debug.apk
```

Or transfer the APK to the device and open it. On Android 8.0+: Settings → Apps → Special app access → Install unknown apps → select the browser or file manager used to download → Allow from this source. On Android 7 and below: Settings → Security → Unknown sources.

#### Remote testers

Email is blocked by Gmail, Outlook, and most providers (`.apk` files are treated as executables).

Option A — Cloud link (simplest, 1–5 testers):

Upload the APK to Google Drive or Dropbox, share the link. Tester opens the link in their phone browser, downloads the APK, and taps to install.

Option B — Firebase App Distribution (ongoing beta):

- Free; upload APK via Firebase console or CLI; add testers by email
- Firebase sends each tester a download link; provides version management and tester analytics
- Requires a Firebase project; see https://firebase.google.com/docs/app-distribution

---

## Testing

[⬑ Back to top](#use-case-matrix)

### Unit tests (devcontainer)

Runs all Rust lib/bin unit tests and any Svelte unit tests:

```sh
scripts/test.sh
```

### E2E tests (devcontainer)

Builds the app binary, starts `tauri-driver`, and runs the smoke test under Xvfb:

```sh
scripts/test-e2e.sh
```

Requires the devcontainer (xvfb, webkitgtk-webdriver, dbus-x11, and tauri-driver installed by `postCreate.sh`).

### Full CI suite

Runs lint → unit → E2E in sequence; exits on first failure:

```sh
scripts/ci.sh
```

Run subsets with flags (combinable):

```sh
scripts/ci.sh --lint          # format check + clippy + svelte-check
scripts/ci.sh --unit          # unit tests only
scripts/ci.sh --e2e           # E2E tests only
scripts/ci.sh --lint --unit   # lint + unit, skip E2E
```

---

## Cleaning the build environment

[⬑ Back to top](#use-case-matrix)

### Rust (Cargo)

Removes all compiled artifacts and intermediate files from `target/`:

```sh
cargo clean
```

Run from the workspace root. The next build starts from scratch. In the devcontainer, `target/` is a named Docker volume — `cargo clean` clears its contents but the volume itself persists.

### Svelte

Removes the compiled frontend bundle:

```sh
bun run --cwd packages/svelte clean
```

The next `bun run --cwd packages/svelte build` (or `tauri-build.sh`/`tauri-dev.sh`) regenerates it.

### Clean everything

```sh
scripts/clean.sh
```

Equivalent to `cargo clean` + Svelte clean. Defined canonically in the root `package.json` `clean` script.

---

## Mobile scaffolding (first-time setup)

[⬑ Back to top](#use-case-matrix)

Run once on a Mac to generate the Xcode and Android Studio project directories:

```sh
source scripts/setenv
scripts/init-mobile.sh
```

Then commit the generated directories:

```sh
git add packages/rust/gen/apple/ packages/rust/gen/android/
git commit -m "chore: add mobile scaffolding"
```

After this, any Mac developer can build for iOS/Android immediately after cloning — without running `init-mobile.sh` again.

---

## Troubleshooting

[⬑ Back to top](#use-case-matrix)

### D-Bus / WebKitGTK errors during E2E tests

Symptom: `Failed to connect to the D-Bus session` or GTK assertion failures.

Fix: The `test-e2e.sh` script uses `dbus-launch xvfb-run -a` automatically. If running cargo directly, prefix with:

```sh
dbus-launch xvfb-run -a cargo test --test smoke_e2e --test-threads=1
```

### Missing `gen/apple/` or `gen/android/` directories

Symptom: `ios-dev.sh` or `android-dev.sh` exits with "run init-mobile.sh first".

Fix: Run `scripts/init-mobile.sh` on a Mac, then commit `gen/apple/` and `gen/android/`.

### Display errors (DISPLAY not set)

Symptom: `Cannot open display` or `GDK_BACKEND` errors outside of `test-e2e.sh`.

Fix: Do not run `tauri-dev.sh` inside the devcontainer — it needs a display. The script detects `$REMOTE_CONTAINERS` and exits with an error. Run it from your host machine.

### `tauri-driver` not found

Symptom: `command not found: tauri-driver` in `test-e2e.sh`.

Fix: Rebuild the devcontainer — `tauri-driver` is installed in `postCreate.sh`. Command Palette → **Dev Containers: Rebuild Container**.
