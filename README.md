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

API credentials in this tree are **placeholders only** (`CASMOS_PLACEHOLDER_*`). Obtain your own [api_id / api_hash](https://core.telegram.org/api/obtaining_api_id) before building a usable client. Do not commit real secrets.

Official Sparkle and App Center update endpoints are blanked. Casmos does not ship in-app updates from osx.telegram.org or App Center.

## Build

See [INSTALL.md](INSTALL.md) for the Mac / Xcode steps.

## Settings

Casmos Settings (General, Appearance, Chat, Translator, Passcode, Experimental) is a P0 shell. Preference keys are stored; extra client features listed in [ROADMAP.md](ROADMAP.md) are not implemented yet.

## License

GPL-2.0. Upstream Telegram for macOS source remains under the same license. Publish your changes.
