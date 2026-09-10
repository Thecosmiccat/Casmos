# How to build Casmos for macOS

Casmos is a branded fork of [TelegramSwift](https://github.com/overtake/TelegramSwift). The product name is **Casmos**. The app bundle ID is `app.casmos.macos`.

You need a Mac with a recent Xcode. This Linux environment does not compile the Mac app.

A **free Apple ID** is enough for a local debug build (Xcode Personal Team). You do not need a paid Apple Developer Program membership to compile and run on your own Mac.

`api_id` / `api_hash` stay placeholders in this tree until Jeffrey provides them. Do not invent or commit keys. DeepL is **not** required for a basic run.

## 1. Clone with nested submodules

HTTPS clone, recursive, so `telegram-ios` and `tg_owt` nested modules come along:

```
git clone https://github.com/Thecosmiccat/Casmos.git --recurse-submodules
cd Casmos
git submodule update --init --recursive
```

If you already cloned without `--recurse-submodules`:

```
git submodule sync --recursive
git submodule update --init --recursive
```

If `configure_frameworks.sh` later fails because `tg_owt` or `telegram-ios` is incomplete:

```
git submodule update --init --recursive --force
cd submodules/tg_owt && git submodule update --init --recursive && cd ../..
cd submodules/telegram-ios && git submodule update --init --recursive && cd ../..
```

`.gitmodules` uses HTTPS. If a nested submodule still prints `git@github.com` / “Permission denied (publickey)”:

```
git config --global url."https://github.com/".insteadOf "git@github.com:"
git submodule sync --recursive
git submodule update --init --recursive
```

Confirm the top-level modules are present (`submodules/telegram-ios`, `submodules/tg_owt`, `submodules/tgcalls`, `submodules/Sparkle`, and the others listed in `.gitmodules`) before continuing.

## 2. Homebrew tools

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install cmake ninja openssl@1.1 zlib autoconf libtool automake yasm nasm meson pkg-config
```

`nasm` is used by OpenH264; `meson` is used by dav1d. If `openssl@1.1` is unavailable from Homebrew, `brew install openssl` is enough for the host tools — the in-tree `core-xprojects/openssl` project still builds the copy the app links.

## 3. Configure frameworks

`scripts/rebuild` is `no` on a clean tree. Leave it `no` for the first configure. Set it to `yes` only to wipe leftover `core-xprojects/*/build` dirs after a failed run.

```
# After a failed configure only:
#   printf 'yes\n' > scripts/rebuild
#   rm -rf core-xprojects/webrtc/build
sh ./scripts/configure_frameworks.sh
```

That script needs Xcode’s command-line tools (`xcode-select -p` should point at an Xcode.app). It builds OpenH264, OpenSSL, libopus, libvpx, Mozjpeg, libwebp, dav1d, ffmpeg, webrtc, and tde2e, then copies headers. First run can take a long time.

If webrtc configure dies on a half-filled build dir:

```
rm -rf core-xprojects/webrtc/build
cd submodules/tg_owt && git submodule update --init --recursive && cd ../..
printf 'yes\n' > scripts/rebuild
sh ./scripts/configure_frameworks.sh
```

Xcode 26: install the Metal Toolchain from Xcode → Settings → Components if the webrtc/ffmpeg steps complain about `metal`.

When it finishes, set `scripts/rebuild` back to `no`.

## 4. API credentials — placeholders until Jeffrey provides them

Leave these values as-is for a compile and first launch. Login and network will not work until real credentials are pasted. **Do not commit real secrets.**

When Jeffrey sends `api_id` / `api_hash`, paste them only in:

`packages/ApiCredentials/Sources/ApiCredentials/Config.swift`

- `apiId` — replace `0` (marker `CASMOS_PLACEHOLDER_API_ID`) with the integer api_id.
- `apiHash` — replace `"CASMOS_PLACEHOLDER_API_HASH"` with the api_hash string.

Do not put keys anywhere else. Do not replace the placeholders in git.

### Team ID (local signing)

Xcode → target **Telegram** (product name Casmos) → Signing & Capabilities → Team. The 10-character Team ID must match these placeholders (`CASMOS_PLACEHOLDER_TEAM_ID` / `CASM0STEAM`):

- `packages/ApiCredentials/Sources/ApiCredentials/Config.swift` (`teamId`)
- `Telegram-Mac/LocalAuth.swift` (`bundleSeedId`)
- `submodules/BuildConfig/Sources/BuildConfig.m` (`bundleSeedId`)

A free Apple ID Personal Team ID is fine for a local run. App Groups use `$(TeamIdentifierPrefix)app.casmos.macos`. If Xcode reports an App Group capability error on a free account, you can still compile; some multi-process features may not activate until a paid team is used.

Get your own keys later at https://core.telegram.org/api/obtaining_api_id only if you are not waiting on Jeffrey. Never commit them.

## 5. Open in Xcode and sign

Open **`Telegram-Mac.xcworkspace`** (not the `.xcodeproj` alone) in the latest Xcode.

- Signing: Automatic signing. Select your team (free Apple ID Personal Team is OK) on:
  - **Telegram** target (display name Casmos, bundle `app.casmos.macos`)
  - **TelegramShare** (`app.casmos.macos.Share`)
  - **FocusIntents** (`app.casmos.macos.FocusIntents`)
- Display name is Casmos (`PRODUCT_NAME` / `CFBundleDisplayName`).
- Sparkle `SFEED_URL` and `APPCENTER_SECRET` are blank on purpose.

Scheme / target to build: **Telegram**. The built app is **Casmos.app**, bundle ID `app.casmos.macos`.

## 6. First launch / Gatekeeper

A local unsigned or ad-hoc signed build is expected. macOS Gatekeeper will often block the first open.

- In Finder: right-click **Casmos.app** → **Open** → **Open**.
- Or System Settings → Privacy & Security → **Open Anyway**.
- If the app was downloaded/copied and still quarantined:

```
xattr -cr /path/to/Casmos.app
```

Then right-click Open again. This is a local unsigned build, not a notarized distribution.

## DeepL is not required

A basic run does not need a DeepL key, the DeepL engine, or translator enabled. Casmos Settings → Translator stays off. Leave the DeepL field empty (`CASMOS_PLACEHOLDER_DEEPL_KEY` is treated as unset).

## Translator (optional Mac QA)

Casmos Settings → Translator: enable, cycle Engine (`system` / `extra` / `yandex` / `deepl`), optional Auto-translate Chats, optional DeepL key field. Message context menu Translate uses the selected engine. Poll and todo lists use the local engine when translator is enabled. DeepL without a local key uses the public web endpoint.

Casmos Settings → General: Keep Original File Names uses the document name in Save and Downloads. Appearance: Compact Chat List (56pt rows) and Monochrome Folders (gray folder tags). Chat: Double-Click Action (default Reply) and Hide Channel Bottom Buttons (collapses the channel Mute / Discuss bar; header actions stay). Experimental: Verbose Logging is **off by default**; turn it on only when you want console and log files. Config: Export / Import a JSON file of `casmos.pref.*` keys (may include a local DeepL key).

Message context menu includes Repeat (resend content in the current chat), Forward without Quote, Details (JSON), and Translate when the translator is on.

This Linux environment cannot compile the Mac app.

## Updates

In-app Sparkle / App Center feeds that pointed at osx.telegram.org, mac-updates.telegram.org, and api.appcenter.ms are disabled. Do not restore those official endpoints for a Casmos build.

## Fork notes from upstream

1. Use your own API ID (Jeffrey’s keys in this project; do not use Telegram’s).
2. Do not call the app Telegram.
3. Do not use the official white paper-plane logo.
4. Follow Telegram’s [security guidelines](https://core.telegram.org/mtproto/security_guidelines).
5. GPL-2.0 requires you to publish your source.
