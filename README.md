# Casmos

<p align="center">
  <img src="Telegram-Mac/Assets.xcassets/AppIcon.appiconset/Logo_512@2x.png" width="125" height="125" alt="Casmos">
</p>

Casmos is an unofficial, open-source macOS client based on the [Telegram for macOS](https://github.com/overtake/TelegramSwift) source. The app is named **Casmos**. It is not affiliated with Telegram FZ-LLC and does not use the official paper-plane logo.

This repository is licensed under the GNU General Public License, version 2.0. See [LICENSE](LICENSE).

Casmos is a **low-leak client**. It does not make you anonymous on the network. Privacy toggles hide things on this Mac.

## Identity

| | |
| --- | --- |
| Display name | Casmos |
| Bundle ID | `app.casmos.macos` |
| Share extension | `app.casmos.macos.Share` |
| Focus Intents | `app.casmos.macos.FocusIntents` |
| Preference keys | `casmos.pref.*` |

Official Sparkle and App Center update endpoints are blank. Casmos does not ship in-app updates from osx.telegram.org or App Center.

## Credentials

Tracked `packages/ApiCredentials/Sources/ApiCredentials/Config.swift` stays placeholders (`apiId` `0`, `CASMOS_PLACEHOLDER_API_HASH`). Do not commit live keys.

The running app reads:

`~/Library/Application Support/Casmos/api-credentials.json`

(`chmod 600`. Not in git.) Get your own `api_id` / `api_hash` at [my.telegram.org](https://my.telegram.org). DeepL is not required for a basic run.

## Features

Chat, themes, and accounts work like a normal Mac messenger. Casmos Settings (General, Appearance, Chat, Passcode, Experimental, Config) stores `casmos.pref.*`. Translator lives under **Language → Translate Messages**.

### Chat

- **Send with Command-Return** — optional; Return still sends when the sending type is set that way
- **Sticker size** — small / medium / large (scales the 208pt chat sticker box; custom emoji stays 112pt)
- **Double-click action** — reply (default), none, reaction, edit, copy, forward, repeat, translate, details
- **Hide Channel Bottom Buttons** — collapses Mute / Discuss on broadcast channels; those stay in the header
- **Message Filter** — comma-separated keywords hide matching incoming text in the chat and list preview on this Mac only (not deleted)
- **Message menu** — Repeat (resend in the current chat), Forward without Quote, Details (JSON snapshot)
- **Chat streaks** — local 1:1 flame on the chat list when you sent and received that day; not uploaded
- **Keep Original File Names** — Save / Downloads use the document name

### Appearance

- **Themes** — Pink, Pink Light, Nord, Dracula, Mocha, Tokyo Night, Gruvbox, Rosé Pine, Rosé Pine Dawn, Everforest, One Dark, Solarized Light, Kanagawa, Blush, Coastal, Wine, Harbor, Royal, Sage, plus the built-in day / dark / system palettes
- **Custom Theme** — full-page studio: pick a screen, then a color or swatch
- **Compact Chat List** — 56pt rows, 36pt avatars
- **Monochrome Folders** — folder tags and tab titles in gray
- **Hide Stories** — removes the chat-list Stories strip and avatar story rings (**on by default**)
- **Profile banners** — local JPEG on your own profile (crop / pan). Not a server profile photo
- **App Icon** — bundled Casmos icon only. Extra icons are **Coming Soon** (Settings → Appearance)

### Privacy and passcode

Defaults that are **on** for a fresh install: Confirm External Links, Hide Phone and Username, Hide Stories, Lock on Sleep, Hide Content in App Switcher. Verbose Logging is **off**. Keep Formatting is **on**.

- **Confirm External Links** — prompt before opening http(s) URLs
- **Hide Phone and Username** — hides your number and @username on your own profile, Settings header, and Edit Account (Username / Change Number stay tappable)
- **Lock on Sleep** — lock when the Mac sleeps or the screensaver starts (needs a passcode to mean much)
- **Hide Content in App Switcher** — blanks App Switcher / Mission Control snapshots when a passcode is set
- **Account passcode** — PBKDF2 hash in the Keychain (`WhenUnlockedThisDeviceOnly`)
- **Hide This Account** — drops the account from switchers until you type that passcode
- **Panic passcode** — hides included accounts for this session; Hide This Account survives quit
- **Logout on Panic** — also signs those accounts out (**off** by default)
- **Unlock Hidden Account** — type the account passcode to bring it back

This is local hide, not network anonymity.

### Translator

Language → Translate Messages.

- Engines: **System** (batch API), **Extra** (web fallback), **Yandex** (local), **DeepL** (local key in prefs when set)
- Auto-translate chats
- Translate chat titles / list names (off by default)
- Do-not-translate language codes
- Keep formatting (default on; Yandex HTML and DeepL `tag_handling` when a local key is set)
- Message / poll / todo translate when translator is on

### Experimental and config

- **Pause Video in Background** — inline video, GIFs, and round videos pause when Casmos is inactive
- **Verbose Logging** — off by default; console and log files when on (no message bodies / phone / `api_hash` in Casmos logs)
- **Export / Import Preferences** — JSON of `casmos.pref.*` (export may include a local DeepL key if you set one)

## Coming Soon / not shipped

| | |
| --- | --- |
| Extra app / Dock icons | **Coming Soon**. Bundled Casmos icon only |
| Touch ID Reveals Hidden Accounts | **NOT WIRED** on Macs without biometrics. With Touch ID it stays off until LocalAuthentication succeeds |
| Cold-start lock | Accepts the app passcode only. Panic / hide are **NOT WIRED** there |
| Keep Deleted Messages | Not shipped (leftover key only) |
| Share extension / Focus Intents persistence | **NOT WIRED** without application-groups on unsigned local builds |
| In-app updates | Endpoints blank on purpose |

See [ROADMAP.md](ROADMAP.md) for leftover later work.

## Build

See [INSTALL.md](INSTALL.md) for recursive submodules, a free Apple ID, Xcode, and Gatekeeper.

| | |
| --- | --- |
| Product / display name | Casmos |
| Target to build | **Telegram** in `Telegram-Mac.xcworkspace` |
| Bundle ID | `app.casmos.macos` |

## License

GPL-2.0. Upstream Telegram for macOS source remains under the same license. Publish your changes.
