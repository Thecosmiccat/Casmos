# How to build Casmos for macOS

Casmos is a branded fork of [TelegramSwift](https://github.com/overtake/TelegramSwift). Use a Mac with a recent Xcode. This environment does not compile the Mac app.

## 1. Clone with submodules

```
git clone https://github.com/Thecosmiccat/Casmos.git --recurse-submodules
cd Casmos
```

If you already cloned without submodules:

```
git submodule update --init --recursive
```

`.gitmodules` uses HTTPS. If a submodule still points at `git@`, switch that URL to HTTPS.

## 2. Homebrew tools

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install cmake ninja openssl@1.1 zlib autoconf libtool automake yasm pkg-config
```

## 3. Configure frameworks

In `scripts/rebuild`, set the rebuild flag from `no` to `yes`, then:

```
sh ./scripts/configure_frameworks.sh
```

## 4. API credentials (required)

Open `packages/ApiCredentials/Sources/ApiCredentials/Config.swift`.

- Replace `CASMOS_PLACEHOLDER_API_ID` (currently `apiId` returns `0`) with your own integer api_id.
- Replace `CASMOS_PLACEHOLDER_API_HASH` with your own api_hash string.
- Set `teamId` to your 10-character Apple Team ID so it matches Xcode application groups (`$(TeamIdentifierPrefix)` in entitlements).

Get credentials at https://core.telegram.org/api/obtaining_api_id. Never commit real secrets.

Also set the same Team ID in:

- `Telegram-Mac/LocalAuth.swift` (`bundleSeedId`)
- `submodules/BuildConfig/Sources/BuildConfig.m` (`bundleSeedId`)

## 5. Open in Xcode

Open `Telegram-Mac.xcworkspace` (not the `.xcodeproj` alone) in the latest Xcode.

- Signing: select your team on the Casmos (Telegram) target, Share, and FocusIntents.
- Bundle IDs are already `app.casmos.macos`, `app.casmos.macos.Share`, and `app.casmos.macos.FocusIntents`.
- Display name is Casmos (`PRODUCT_NAME` / `CFBundleDisplayName`).
- Sparkle `SFEED_URL` and `APPCENTER_SECRET` are blank on purpose.

Build the **Telegram** target. The product name is Casmos.

## Translator (Mac QA)

Casmos Settings → Translator: enable, cycle Engine (`system` / `extra` / `yandex` / `deepl`), optional Auto-translate Chats, optional DeepL key field. Message context menu Translate uses the selected engine. Poll and todo lists use the local engine when translator is enabled. DeepL without a local key uses the public web endpoint.

Casmos Settings → General: Keep Original File Names uses the document name in Save and Downloads. Appearance: Compact Chat List (56pt rows) and Monochrome Folders (gray folder tags). Experimental: Verbose Logging writes to the console and log files.

This Linux environment cannot compile the Mac app.

## Updates

In-app Sparkle / App Center feeds that pointed at osx.telegram.org, mac-updates.telegram.org, and api.appcenter.ms are disabled. Do not restore those official endpoints for a Casmos build.

## Fork notes from upstream

1. Use your own API ID.
2. Do not call the app Telegram.
3. Do not use the official white paper-plane logo.
4. Follow Telegram’s [security guidelines](https://core.telegram.org/mtproto/security_guidelines).
5. GPL-2.0 requires you to publish your source.
