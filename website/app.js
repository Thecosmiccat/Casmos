(() => {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const rain = document.querySelector(".matrix-rain");

  if (rain && !reduced) {
    const ctx = rain.getContext("2d");
    if (ctx) {
      const fontSize = 14;
      const chars = "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ1234567890";
      let drops = [];
      let timer = 0;

      const size = () => {
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        const w = window.innerWidth;
        const h = window.innerHeight;
        rain.width = Math.floor(w * dpr);
        rain.height = Math.floor(h * dpr);
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
        drops = Array.from({ length: Math.max(1, Math.floor(w / fontSize)) }, () => Math.random() * (h / fontSize));
        ctx.fillStyle = "#000000";
        ctx.fillRect(0, 0, w, h);
      };

      const draw = () => {
        const w = window.innerWidth;
        const h = window.innerHeight;
        ctx.fillStyle = "rgba(0, 0, 0, 0.08)";
        ctx.fillRect(0, 0, w, h);
        ctx.font = `${fontSize}px ui-monospace, SFMono-Regular, Menlo, monospace`;
        ctx.fillStyle = "rgba(255, 255, 255, 0.42)";
        for (let i = 0; i < drops.length; i += 1) {
          ctx.fillText(chars[Math.floor(Math.random() * chars.length)] || "", i * fontSize, drops[i] * fontSize);
          if (drops[i] * fontSize > h && Math.random() > 0.975) drops[i] = 0;
          drops[i] += 1;
        }
      };

      size();
      draw();
      window.addEventListener("resize", () => {
        size();
        draw();
      });
      timer = window.setInterval(() => {
        if (!document.hidden) draw();
      }, 80);
      window.addEventListener("pagehide", () => window.clearInterval(timer), { once: true });
    }
  }

  const mark = document.querySelector("[data-roll]");
  if (mark) {
    const text = mark.getAttribute("data-roll") || "CASMOS";
    const minCycles = 3;
    const cycleVariance = 3;
    const baseDuration = 2.4;
    const durationVariance = 1.2;

    const mulberry32 = (seed) => () => {
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };

    const expoOut = (t) => 1 - Math.pow(2, -10 * t);

    text.split("").forEach((char, index) => {
      if (char === " ") {
        const space = document.createElement("span");
        space.setAttribute("aria-hidden", "true");
        space.innerHTML = "&nbsp;";
        mark.append(space);
        return;
      }

      const rand = mulberry32(index * 1013 + 7);
      const cycles = minCycles + Math.floor(rand() * cycleVariance);
      const duration = baseDuration + rand() * durationVariance;

      const cell = document.createElement("span");
      cell.className = "reel-cell";
      cell.setAttribute("aria-hidden", "true");

      const ghost = document.createElement("span");
      ghost.className = "reel-ghost";
      ghost.textContent = char;

      const mask = document.createElement("span");
      mask.className = "reel-mask";

      const reel = document.createElement("span");
      reel.className = "reel";
      reel.dataset.to = String(cycles);
      reel.dataset.duration = String(duration);
      reel.style.setProperty("--k", "0");

      for (let copy = 0; copy < cycles + 1; copy += 1) {
        const slot = document.createElement("span");
        slot.textContent = char;
        reel.append(slot);
      }

      mask.append(reel);
      cell.append(ghost, mask);
      mark.append(cell);
    });

    const reels = mark.querySelectorAll("[data-to]");
    if (reduced) {
      reels.forEach((reel) => reel.style.setProperty("--k", reel.dataset.to || "0"));
    } else {
      let waitTimer = 0;
      const spin = () => {
        window.clearTimeout(waitTimer);
        let left = reels.length;
        reels.forEach((reel) => {
          const to = Number(reel.dataset.to);
          const ms = Number(reel.dataset.duration) * 1000;
          reel.style.setProperty("--k", "0");
          const start = performance.now();
          const tick = (now) => {
            const t = Math.min(1, (now - start) / ms);
            reel.style.setProperty("--k", String(t >= 1 ? to : to * expoOut(t)));
            if (t < 1) {
              requestAnimationFrame(tick);
              return;
            }
            left -= 1;
            if (left === 0) waitTimer = window.setTimeout(spin, 9000);
          };
          requestAnimationFrame(tick);
        });
      };
      spin();
      window.addEventListener("pagehide", () => window.clearTimeout(waitTimer), { once: true });
    }
  }

  const dialog = document.querySelector(".feature-dialog");
  if (!dialog) return;

  const visual = document.getElementById("dialog-visual");
  const sub = document.getElementById("dialog-sub");
  const title = document.getElementById("dialog-title");
  const body = document.getElementById("dialog-body");
  const cardsOf = () => document.querySelectorAll(".feature-card");
  let lastCard = null;

  const openFrom = (card) => {
    lastCard = card;
    const shot = card.querySelector(".app-shot");
    visual.replaceChildren(shot ? shot.cloneNode(true) : document.createTextNode(""));
    sub.textContent = card.dataset.subtitle || "";
    title.textContent = card.dataset.title || "";
    body.textContent = card.dataset.body || "";
    cardsOf().forEach((item) => item.setAttribute("aria-expanded", item === card ? "true" : "false"));
    dialog.showModal();
    dialog.querySelector(".dialog-close")?.focus();
  };

  const close = () => {
    cardsOf().forEach((item) => item.setAttribute("aria-expanded", "false"));
    if (typeof lastCard?.focus === "function") lastCard.focus();
  };

  document.addEventListener("click", (event) => {
    const card = event.target.closest(".feature-card");
    if (!card) return;
    openFrom(card);
  });

  cardsOf().forEach((card) => card.setAttribute("aria-expanded", "false"));

  dialog.addEventListener("click", (event) => {
    const box = dialog.getBoundingClientRect();
    const inside =
      event.clientX >= box.left &&
      event.clientX <= box.right &&
      event.clientY >= box.top &&
      event.clientY <= box.bottom;
    if (!inside) dialog.close();
  });

  dialog.addEventListener("close", close);
})();
