# Casmos

<p align="center">
  <img src="Telegram-Mac/Assets.xcassets/AppIcon.appiconset/Logo_1024.png" width="125" height="125" alt="Casmos">
</p>

Casmos is an unofficial, open-source macOS client based on the [Telegram for macOS](https://github.com/overtake/TelegramSwift) source. The app is named **Casmos**. It is not Telegram, is not affiliated with Telegram FZ-LLC, and does not use the official paper-plane logo.

This repository is licensed under the GNU General Public License, version 2.0. See [LICENSE](LICENSE).

## Identity

| | |
| --- | --- |
| Display name | Casmos |
| Bundle ID | `app.casmos.macos` |
| Share extension | `app.casmos.macos.Share` |
| Focus Intents | `app.casmos.macos.FocusIntents` |
| Preference keys | `casmos.pref.*` |

API credentials in this tree are **placeholders only** (`CASMOS_PLACEHOLDER_*`) until Jeffrey provides `api_id` / `api_hash`. Paste them in `packages/ApiCredentials/Sources/ApiCredentials/Config.swift`. Do not commit real secrets. DeepL is not required for a basic run.

Official Sparkle and App Center update endpoints are blanked. Casmos does not ship in-app updates from osx.telegram.org or App Center.

## Build

See [INSTALL.md](INSTALL.md) for the local Mac / Xcode path: recursive submodules, a free Apple ID, Gatekeeper “Open Anyway”, and where to paste API keys later.

| | |
| --- | --- |
| Product / display name | Casmos |
| Target to build | **Telegram** in `Telegram-Mac.xcworkspace` |
| Bundle ID | `app.casmos.macos` |

## Settings

Casmos Settings (General, Appearance, Chat, Translator, Passcode, Experimental, Config) stores `casmos.pref.*` keys. Fresh-install defaults: Confirm External Links, Lock on Sleep, and Hide Content in App Switcher are on; Verbose Logging is off. Thin P1 hooks apply sticker size, extra-engine translate routing, pause-video-in-background, local translator engines (yandex / deepl) plus message / poll / todo translate, keep original file names, compact chat list, monochrome folders, verbose logging, double-click action, hide channel bottom buttons, message Repeat / Details / no-quote forward, and preference JSON export/import. See [ROADMAP.md](ROADMAP.md).

## License

GPL-2.0. Upstream Telegram for macOS source remains under the same license. Publish your changes.
