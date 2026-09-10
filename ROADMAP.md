# Casmos roadmap

## P0 (this tree)

- Casmos identity: display name, bundle IDs, icon that is not the official paper plane
- API credentials as `CASMOS_PLACEHOLDER_*` only
- Casmos Settings shell: General, Appearance, Chat, Translator, Passcode, Experimental (`casmos.pref.*`)
- Modular `packages/Casmos`
- Official Sparkle and App Center update endpoints blanked
- Mac Xcode build notes in INSTALL.md
- Send with Command-Return, confirm external links, lock on sleep, hide content in App Switcher

## P1 (thin hooks in this tree)

- Sticker size: `casmos.pref.chat.stickerSize` scales the 208pt chat sticker box (small / medium / large). Custom emoji stays 112pt.
- Translator extra engine: when translator is enabled and engine is `extra`, `translateBlocks` uses the existing web fallback instead of the official API. `system` leaves official routing. This is not a new translate engine.
- Pause video when the app is in the background: inline chat video, GIFs, and round videos pause when Casmos is not the active app.

## Later

- Keep Original File Names, compact chat list, monochrome folders, verbose logging (keys stored only)
- Full multi-engine translator (separate engines, not only the existing fallback)
- A signed Mac build with real `api_id` / `api_hash` / Team ID (placeholders stay in this tree)
