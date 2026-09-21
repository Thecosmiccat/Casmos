(() => {
  const catalog = document.getElementById("feature-catalog");
  if (!catalog) return;

  const themes = [
    ["Pink", "#e23d8c"],
    ["Pink Light", "#f4b6d2"],
    ["Nord", "#2e3440"],
    ["Dracula", "#282a36"],
    ["Mocha", "#1e1e2e"],
    ["Tokyo Night", "#1a1b26"],
    ["Gruvbox", "#282828"],
    ["Rosé Pine", "#191724"],
    ["Rosé Pine Dawn", "#faf4ed"],
    ["Everforest", "#2d353b"],
    ["One Dark", "#282c34"],
    ["Solarized Light", "#fdf6e3"],
    ["Kanagawa", "#1f1f28"],
    ["Blush", "#4a3038"],
    ["Coastal", "#1c3340"],
    ["Wine", "#3a1d28"],
    ["Harbor", "#1a2838"],
    ["Royal", "#24183a"],
    ["Sage", "#243028"],
    ["Day", "#f4f4f4"],
    ["Dark", "#111111"],
  ];

  const sections = [
    {
      title: "General",
      items: [
        {
          name: "Keep Original File Names",
          sub: "General",
          subtitle: "General",
          body: "Save and Downloads use the document name instead of a generated one.",
          head: "GENERAL",
          rows: [
            ["Keep Original File Names", "off"],
            ["Confirm External Links", "on"],
            ["Hide Phone and Username", "on"],
          ],
        },
        {
          name: "Confirm External Links",
          sub: "General",
          subtitle: "General. Default on",
          body: "Prompts before opening http(s) URLs. On by default.",
          head: "GENERAL",
          rows: [
            ["Keep Original File Names", "off"],
            ["Confirm External Links", "on"],
            ["Hide Phone and Username", "on"],
          ],
        },
        {
          name: "Hide Phone and Username",
          sub: "General",
          subtitle: "General. Default on",
          body: "Removes your number and @username from your own profile, Settings header, and Edit Account. Username and Change Number stay tappable.",
          head: "GENERAL",
          rows: [
            ["Keep Original File Names", "off"],
            ["Confirm External Links", "on"],
            ["Hide Phone and Username", "on"],
          ],
        },
      ],
    },
    {
      title: "Appearance",
      items: [
        {
          name: "Custom Theme",
          sub: "Appearance",
          subtitle: "Appearance",
          body: "Opens a full-page studio. Tap a screen, then tap a color or a swatch.",
          head: "APPEARANCE",
          rows: [
            ["Custom Theme", "chev"],
            ["Compact Chat List", "off"],
            ["Monochrome Folders", "off"],
            ["Hide Stories", "on"],
          ],
        },
        {
          name: "Themes",
          sub: "Appearance",
          subtitle: "Appearance",
          body: "Palettes: Pink, Pink Light, Nord, Dracula, Mocha, Tokyo Night, Gruvbox, Rosé Pine, Rosé Pine Dawn, Everforest, One Dark, Solarized Light, Kanagawa, Blush, Coastal, Wine, Harbor, Royal, Sage, plus day, dark, and system. Extra app icons are Coming soon.",
          head: "APPEARANCE",
          theme: true,
        },
        {
          name: "Compact Chat List",
          sub: "Appearance",
          subtitle: "Appearance",
          body: "Uses 56pt rows and 36pt avatars in the chat list. Topic lists use the same row height.",
          head: "APPEARANCE",
          rows: [
            ["Custom Theme", "chev"],
            ["Compact Chat List", "off"],
            ["Monochrome Folders", "off"],
            ["Hide Stories", "on"],
          ],
        },
        {
          name: "Monochrome Folders",
          sub: "Appearance",
          subtitle: "Appearance",
          body: "Folder tags and folder tab titles draw in gray instead of assigned colors.",
          head: "APPEARANCE",
          rows: [
            ["Custom Theme", "chev"],
            ["Compact Chat List", "off"],
            ["Monochrome Folders", "off"],
            ["Hide Stories", "on"],
          ],
        },
        {
          name: "Hide Stories",
          sub: "Appearance",
          subtitle: "Appearance. Default on",
          body: "Removes the chat-list Stories strip and avatar story rings. On by default. Stories stay on Telegram.",
          head: "APPEARANCE",
          rows: [
            ["Custom Theme", "chev"],
            ["Compact Chat List", "off"],
            ["Monochrome Folders", "off"],
            ["Hide Stories", "on"],
          ],
        },
        {
          name: "Profile banners",
          sub: "Appearance",
          subtitle: "Own profile",
          body: "A local JPEG on your own profile, with crop and pan. It is not a server profile photo.",
          head: "PROFILE",
          rows: [
            ["Profile Banner", "chev"],
            ["Hide Phone and Username", "on"],
          ],
        },
        {
          name: "App Icon",
          sub: "Appearance",
          subtitle: "Appearance. Coming soon",
          body: "The bundled Casmos icon is the one that ships. Extra Dock and app icons are Coming soon.",
          head: "APPEARANCE",
          rows: [["App Icon", "Coming soon ›"]],
        },
      ],
    },
    {
      title: "Chat",
      items: [
        {
          name: "Send with Command-Return",
          sub: "Chat",
          subtitle: "Chat",
          body: "Command-Return sends when this is on. Return still can, if the sending type is set that way.",
          head: "CHAT",
          rows: [
            ["Send with Command-Return", "off"],
            ["Sticker Size", "Medium ›"],
            ["Double-Click Action", "Reply ›"],
            ["Hide Channel Bottom Buttons", "off"],
          ],
        },
        {
          name: "Sticker Size",
          sub: "Chat",
          subtitle: "Chat. Default Medium",
          body: "Small, Medium, or Large. Scales the 208pt chat sticker box. Custom emoji stays 112pt.",
          head: "CHAT",
          rows: [
            ["Send with Command-Return", "off"],
            ["Sticker Size", "Medium ›"],
            ["Double-Click Action", "Reply ›"],
          ],
        },
        {
          name: "Double-Click Action",
          sub: "Chat",
          subtitle: "Chat. Default Reply",
          body: "Runs on a chat bubble: Reply, None, Reaction, Edit, Copy, Forward, Repeat, Translate, or Details. Default is Reply.",
          head: "CHAT",
          rows: [
            ["Sticker Size", "Medium ›"],
            ["Double-Click Action", "Reply ›"],
            ["Hide Channel Bottom Buttons", "off"],
          ],
        },
        {
          name: "Hide Channel Bottom Buttons",
          sub: "Chat",
          subtitle: "Chat",
          body: "Collapses the Mute and Discuss bar on broadcast channels. Mute and discussion stay in the chat header.",
          head: "CHAT",
          rows: [
            ["Double-Click Action", "Reply ›"],
            ["Hide Channel Bottom Buttons", "off"],
          ],
        },
        {
          name: "Keep Deleted Messages",
          sub: "Chat",
          subtitle: "Chat. Default off",
          body: "Keeps messages this Mac already downloaded after someone else deletes them, including while Casmos is in the background. Those bubbles show Deleted. Messages you delete, secret chats, and auto-delete timers still go. A message that never reached this Mac cannot be recovered.",
          head: "CHAT",
          rows: [
            ["Hide Channel Bottom Buttons", "off"],
            ["Keep Deleted Messages", "off"],
          ],
        },
        {
          name: "Message Filter",
          sub: "Chat",
          subtitle: "Chat",
          body: "Hides incoming text that contains a comma-separated keyword on this Mac only. It does not delete messages. Placeholder in Settings: spam, promo, keyword.",
          head: "CHAT",
          rows: [
            ["Hide Channel Bottom Buttons", "off"],
            ["field", "spam, promo, keyword"],
          ],
        },
        {
          name: "Message menu",
          sub: "Chat",
          subtitle: "Chat",
          body: "Repeat resends in the current chat. Forward without Quote and Details (a JSON snapshot) live on the message menu.",
          head: "MESSAGE",
          rows: [
            ["Repeat", "chev"],
            ["Forward without Quote", "chev"],
            ["Details", "chev"],
          ],
        },
        {
          name: "Chat streaks",
          sub: "Chat",
          subtitle: "Chat list",
          body: "A local 1:1 flame on the chat list when you sent and received that day. It is not uploaded.",
          head: "CHAT LIST",
          rows: [["Daily streak", "Local only"]],
        },
      ],
    },
    {
      title: "Passcode",
      items: [
        {
          name: "Lock on Sleep",
          sub: "Passcode",
          subtitle: "Passcode. Default on",
          body: "Locks when the Mac sleeps or the screensaver starts. Needs a passcode to mean much. On by default.",
          head: "PASSCODE",
          rows: [
            ["Lock on Sleep", "on"],
            ["Hide Content in App Switcher", "on"],
            ["Set Account Passcode", "chev"],
          ],
        },
        {
          name: "Hide Content in App Switcher",
          sub: "Passcode",
          subtitle: "Passcode. Default on",
          body: "Blanks App Switcher and Mission Control snapshots when a passcode is set. On by default.",
          head: "PASSCODE",
          rows: [
            ["Lock on Sleep", "on"],
            ["Hide Content in App Switcher", "on"],
            ["Set Account Passcode", "chev"],
          ],
        },
        {
          name: "Account passcode",
          sub: "Passcode",
          subtitle: "Passcode",
          body: "Stored as a PBKDF2 hash in the Keychain with WhenUnlockedThisDeviceOnly. Set, change, or remove it here.",
          head: "PASSCODE",
          rows: [
            ["Set Account Passcode", "chev"],
            ["Hide This Account", "off"],
            ["Unlock Hidden Account", "chev"],
          ],
        },
        {
          name: "Hide This Account",
          sub: "Passcode",
          subtitle: "Passcode",
          body: "Drops this account from switchers until you type that account passcode. It stays after quit.",
          head: "PASSCODE",
          rows: [
            ["Hide This Account", "off"],
            ["Include in Panic", "off"],
            ["Unlock Hidden Account", "chev"],
          ],
        },
        {
          name: "Panic passcode",
          sub: "Passcode",
          subtitle: "Passcode",
          body: "Hides included accounts for this session. Hide This Account survives quit. Include in Panic picks which accounts go with it.",
          head: "PASSCODE",
          rows: [
            ["Include in Panic", "off"],
            ["Set Panic Passcode", "chev"],
            ["Logout on Panic", "off"],
          ],
        },
        {
          name: "Touch ID Reveals Hidden Accounts",
          sub: "Passcode",
          subtitle: "Passcode",
          body: "Stays off until LocalAuthentication succeeds. On a Mac without Touch ID or Face ID the row shows NOT WIRED. Cold-start lock only accepts the app passcode.",
          head: "PASSCODE",
          rows: [
            ["Touch ID Reveals Hidden Accounts", "NOT WIRED"],
            ["Unlock Hidden Account", "chev"],
          ],
        },
        {
          name: "Logout on Panic",
          sub: "Passcode",
          subtitle: "Passcode. Default off",
          body: "Also signs the included accounts out. Off by default.",
          head: "PASSCODE",
          rows: [
            ["Set Panic Passcode", "chev"],
            ["Logout on Panic", "off"],
            ["Unlock Hidden Account", "chev"],
          ],
        },
        {
          name: "Unlock Hidden Account",
          sub: "Passcode",
          subtitle: "Passcode",
          body: "Type the account passcode to bring a hidden account back.",
          head: "PASSCODE",
          rows: [
            ["Hide This Account", "off"],
            ["Unlock Hidden Account", "chev"],
          ],
        },
      ],
    },
    {
      title: "Translator",
      items: [
        {
          name: "Translate Messages",
          sub: "Language",
          subtitle: "Language. Translate Messages",
          body: "Engines: System, Extra (web fallback), Yandex (local), and DeepL (local key in prefs when set). Lives under Language, not Casmos Settings.",
          head: "TRANSLATE MESSAGES",
          rows: [
            ["Translate Messages", "off"],
            ["Engine", "System ›"],
            ["Keep Formatting", "on"],
          ],
        },
        {
          name: "Auto-translate",
          sub: "Language",
          subtitle: "Language. Translate Messages",
          body: "Auto-translates chat messages with the selected engine.",
          head: "TRANSLATE MESSAGES",
          rows: [
            ["Translate Messages", "off"],
            ["Auto-translate", "off"],
            ["Engine", "System ›"],
          ],
        },
        {
          name: "Translate chat titles",
          sub: "Language",
          subtitle: "Language. Default off",
          body: "Translates chat titles and one-line list names. Off by default.",
          head: "TRANSLATE MESSAGES",
          rows: [
            ["Auto-translate", "off"],
            ["Translate chat titles", "off"],
            ["Keep Formatting", "on"],
          ],
        },
        {
          name: "Do not translate",
          sub: "Language",
          subtitle: "Language. Translate Messages",
          body: "Comma-separated language codes skipped by auto-translate and the Translate menu. Combined with the official Language skip list.",
          head: "TRANSLATE MESSAGES",
          rows: [
            ["Do not translate", "chev"],
            ["field", "en, de"],
          ],
        },
        {
          name: "Keep Formatting",
          sub: "Language",
          subtitle: "Language. Default on",
          body: "On by default. Yandex sends HTML and restores bold, italic, underline, strike, code, links, spoilers, and quotes. DeepL does the same via tag handling when a local key is set. Extra web fallback and DeepL without a key stay plain.",
          head: "TRANSLATE MESSAGES",
          rows: [
            ["Engine", "System ›"],
            ["Keep Formatting", "on"],
            ["DeepL key", "chev"],
          ],
        },
      ],
    },
    {
      title: "Experimental and Config",
      items: [
        {
          name: "Pause Video in Background",
          sub: "Experimental",
          subtitle: "Experimental",
          body: "Pauses inline chat video, GIFs, and round videos when Casmos is not the active app.",
          head: "EXPERIMENTAL",
          rows: [
            ["Pause Video in Background", "off"],
            ["Verbose Logging", "off"],
          ],
        },
        {
          name: "Verbose Logging",
          sub: "Experimental",
          subtitle: "Experimental. Default off",
          body: "Off by default. When on, writes Casmos and network logs to the console and log files. Casmos logs are not supposed to include message bodies, phone numbers, or api_hash.",
          head: "EXPERIMENTAL",
          rows: [
            ["Pause Video in Background", "off"],
            ["Verbose Logging", "off"],
          ],
        },
        {
          name: "Export Preferences",
          sub: "Config",
          subtitle: "Config",
          body: "Writes a JSON file of casmos.pref.* keys. Export may include a local DeepL key if you set one.",
          head: "CONFIG",
          rows: [
            ["Export Preferences", "chev"],
            ["Import Preferences", "chev"],
          ],
        },
        {
          name: "Import Preferences",
          sub: "Config",
          subtitle: "Config",
          body: "Reads a JSON file of casmos.pref.* keys. Unknown keys are ignored.",
          head: "CONFIG",
          rows: [
            ["Export Preferences", "chev"],
            ["Import Preferences", "chev"],
          ],
        },
      ],
    },
  ];

  const node = (tag, className) => {
    const el = document.createElement(tag);
    if (className) el.className = className;
    return el;
  };

  const text = (tag, className, value) => {
    const el = node(tag, className);
    el.textContent = value;
    return el;
  };

  const accessory = (kind) => {
    if (kind === "on" || kind === "off") {
      const sw = node("span", kind === "on" ? "sw on" : "sw");
      sw.setAttribute("aria-hidden", "true");
      return sw;
    }
    if (kind === "chev") return text("span", "chev", "›");
    return text("span", "meta", kind);
  };

  const shotFor = (item) => {
    const shot = node("span", "app-shot");
    shot.setAttribute("aria-hidden", "true");
    shot.append(text("span", "app-shot-bar", "Casmos Settings"), text("span", "app-shot-head", item.head));
    const group = node("span", "app-group");

    if (item.theme) {
      group.append(row("Custom Theme", "chev"));
      const swatches = node("span", "app-swatches");
      themes.forEach(([label, color]) => {
        const chip = node("span", "chip");
        chip.title = label;
        chip.style.background = color;
        swatches.append(chip);
      });
      const system = node("span", "chip");
      system.title = "System";
      system.style.background = "linear-gradient(90deg,#f4f4f4 50%,#111 50%)";
      swatches.append(system);
      group.append(swatches);
      group.append(
        text(
          "span",
          "app-swatch-names",
          "Pink, Pink Light, Nord, Dracula, Mocha, Tokyo Night, Gruvbox, Rosé Pine, Rosé Pine Dawn, Everforest, One Dark, Solarized Light, Kanagawa, Blush, Coastal, Wine, Harbor, Royal, Sage, day, dark, system",
        ),
      );
    } else {
      item.rows.forEach(([label, kind]) => {
        if (label === "field") {
          group.append(text("span", "app-field", kind));
          return;
        }
        group.append(row(label, kind));
      });
    }

    shot.append(group);
    return shot;
  };

  const row = (label, kind) => {
    const line = node("span", "app-row");
    line.append(text("span", "", label), accessory(kind));
    return line;
  };

  sections.forEach((section) => {
    const wrap = node("section", "feature-section");
    wrap.setAttribute("aria-labelledby", `feat-${section.title.toLowerCase().replace(/\s+/g, "-")}`);
    const heading = text("h2", "band-title", section.title);
    heading.id = `feat-${section.title.toLowerCase().replace(/\s+/g, "-")}`;
    wrap.append(heading);

    const grid = node("div", "feature-grid");
    section.items.forEach((item) => {
      const card = node("button", "feature-card");
      card.type = "button";
      card.dataset.title = item.name;
      card.dataset.subtitle = item.subtitle;
      card.dataset.body = item.body;
      const copy = node("span", "feature-copy");
      copy.append(text("span", "feature-sub", item.sub), text("span", "feature-name", item.name));
      card.append(shotFor(item), node("span", "feature-shade"), copy);
      grid.append(card);
    });
    wrap.append(grid);
    catalog.append(wrap);
  });
})();
