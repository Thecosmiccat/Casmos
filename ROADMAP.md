# Casmos roadmap

## P0 (this tree)

- Casmos identity: display name, bundle IDs, icon that is not the official paper plane
- API credentials as `CASMOS_PLACEHOLDER_*` only
- Casmos Settings shell: General, Appearance, Chat, Translator, Passcode, Experimental (`casmos.pref.*`)
- Modular `packages/Casmos`
- Official Sparkle and App Center update endpoints blanked
- Mac Xcode build notes in INSTALL.md (free Apple ID, Gatekeeper, recursive submodules, placeholders until Jeffrey provides keys)
- Send with Command-Return
- Confirm external links, lock on sleep, hide content in App Switcher — **on by default** (`casmos.pref.general.confirmLinkOpens`, `casmos.pref.passcode.autoLockOnSleep`, `casmos.pref.passcode.hideContentInAppSwitcher`)
- Hide phone and @username on your own profile UI — **on by default** (`casmos.pref.privacy.hideOwnPhoneAndUsername`)
- Hide Stories strip on the chat list — **on by default** (`casmos.pref.appearance.hideStories`)

## P1 (thin hooks in this tree)

- Sticker size: `casmos.pref.chat.stickerSize` scales the 208pt chat sticker box (small / medium / large). Custom emoji stays 112pt.
- Translator extra engine: when translator is enabled and engine is `extra`, `translateBlocks` uses the existing web fallback instead of the official API. `system` leaves official routing.
- Pause video when the app is in the background: inline chat video, GIFs, and round videos pause when Casmos is not the active app.
- Multi-engine translator: `yandex` and `deepl` are local engines (DeepL uses `casmos.pref.translator.deeplKey` when set). Message context menu Translate uses the selected engine when translator is enabled. Auto-translate chats is `casmos.pref.translator.auto`. Poll and todo messages use the local engine when translator is on (official attributes still apply when present).
- Keep Original File Names: Save / Downloads prefer the document name (`casmos.pref.general.keepOriginalFileNames`).
- Compact Chat List: 56pt rows and 36pt avatars (`casmos.pref.appearance.compactChatList`). Topic lists use the same row height.
- Monochrome Folders: folder tags and folder tab titles use gray instead of assigned colors (`casmos.pref.appearance.monochromeFolders`).
- Verbose Logging: **off by default**; console and file logs when enabled (`casmos.pref.experimental.verboseLogging`).
- Double-click action: `casmos.pref.chat.doubleTapAction` (`reply` default, plus none / reaction / edit / copy / forward / repeat / translate / details).
- Hide channel bottom buttons: `casmos.pref.chat.hideChannelBottomButtons` collapses the Mute / Discuss input bar on broadcast channels. Mute and discussion stay in the chat header.
- Message menu: Repeat (resend content in the current chat), Forward without Quote (`hideNames`), Details (JSON snapshot). Translate remains on the context menu when translator is enabled.
- Config export/import: Casmos Settings → Config writes/reads a JSON file of `casmos.pref.*` keys. Export may include a local DeepL key if one is set.

## P2 (this tree)

- Do not translate: `casmos.pref.translator.doNotTranslate` is a comma-separated language-code list in Casmos Settings → Translator. Combined with Language settings. Empty Casmos + empty official lists skip the app language.
- Keep formatting: `casmos.pref.translator.keepFormatting` (default on). Yandex sends HTML (`format=html`) and restores bold / italic / underline / strike / code / links / spoilers / quotes. DeepL does the same via official `tag_handling` when a local key is set. Extra web fallback and DeepL-without-key stay plain. Poll and todo option entities stay plain.

## Later (needs Jeffrey / live API — not in this overnight branch)
- A signed Mac build with real `api_id` / `api_hash` / Team ID (placeholders stay in this tree)
- Workers AI / Cloudflare transcription (no free anonymous path; not stubbed in this tree)
