/* ═══════════ APRSlocus 官网交互 ═══════════ */
(function () {
  "use strict";

  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ── 进入动画：加载后淡出启动遮罩，触发 Hero 依次入场 ── */
  const preloader = document.getElementById("preloader");
  const finishEnter = () => {
    if (preloader) preloader.classList.add("hide");
    document.body.classList.add("loaded");
  };
  if (prefersReduced) {
    finishEnter();
  } else {
    // load 完成后稍等片刻，让雷达转几圈再淡出；超时兜底防止卡住
    window.addEventListener("load", () => setTimeout(finishEnter, 420), { once: true });
    setTimeout(finishEnter, 3200);
  }

  /* ── 导航栏：滚动收缩 + 移动端菜单 ── */
  const nav = document.getElementById("nav");
  const backTop = document.getElementById("backTop");
  const burger = document.getElementById("navBurger");
  const navLinks = document.getElementById("navLinks");

  function onScroll() {
    const y = window.scrollY;
    nav.classList.toggle("scrolled", y > 30);
    backTop.classList.toggle("show", y > 600);
  }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  burger.setAttribute("aria-expanded", "false");  // 屏幕阅读器要能感知抽屉开合
  burger.addEventListener("click", () => {
    burger.classList.toggle("open");
    navLinks.classList.toggle("open");
    const open = navLinks.classList.contains("open");
    burger.setAttribute("aria-expanded", String(open));
    document.body.style.overflow = open ? "hidden" : "";
  });
  navLinks.querySelectorAll("a").forEach((a) =>
    a.addEventListener("click", () => {
      burger.classList.remove("open");
      navLinks.classList.remove("open");
      burger.setAttribute("aria-expanded", "false");
      document.body.style.overflow = "";
    })
  );

  /* ── 滚动进度条 + 回到顶部进度环 ── */
  const scrollProgress = document.getElementById("scrollProgress");
  const ringFg = document.getElementById("ringFg");
  const CIRC = 106.8; // 半径 17 的周长
  function updateProgress() {
    const doc = document.documentElement;
    const max = doc.scrollHeight - window.innerHeight;
    const p = max > 0 ? Math.min(window.scrollY / max, 1) : 0;
    if (scrollProgress) scrollProgress.style.transform = "scaleX(" + p + ")";
    if (ringFg) ringFg.style.strokeDashoffset = (CIRC * (1 - p)).toFixed(1);
  }
  window.addEventListener("scroll", updateProgress, { passive: true });
  updateProgress();

  /* ── 导航高亮（Scrollspy） ── */
  const sections = Array.from(document.querySelectorAll("section[id]"));
  const navAnchors = Array.from(document.querySelectorAll(".nav-links a[href^='#']"));
  if ("IntersectionObserver" in window && sections.length) {
    const spy = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            navAnchors.forEach((a) =>
              a.classList.toggle("active", a.getAttribute("href") === "#" + e.target.id)
            );
          }
        });
      },
      { rootMargin: "-45% 0px -50% 0px" }
    );
    sections.forEach((s) => spy.observe(s));
  }

  /* ── 卡片鼠标光晕跟随 ── */
  document.querySelectorAll(".card").forEach((card) => {
    card.addEventListener("mousemove", (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty("--mx", ((e.clientX - r.left) / r.width) * 100 + "%");
      card.style.setProperty("--my", ((e.clientY - r.top) / r.height) * 100 + "%");
    });
  });

  /* ── 复制信标 + Toast ── */
  const copyBtn = document.getElementById("copyBeacon");
  let toastEl = null;
  function showToast(text) {
    if (!toastEl) {
      toastEl = document.createElement("div");
      toastEl.className = "toast";
      document.body.appendChild(toastEl);
    }
    toastEl.textContent = text;
    toastEl.classList.add("show");
    clearTimeout(toastEl._t);
    toastEl._t = setTimeout(() => toastEl.classList.remove("show"), 1800);
  }
  if (copyBtn) {
    const beaconCode = document.querySelector(".beacon-code code");
    copyBtn.addEventListener("click", async () => {
      const text = beaconCode ? beaconCode.innerText : "";
      try {
        await navigator.clipboard.writeText(text);
      } catch (err) {
        const ta = document.createElement("textarea");
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      }
      copyBtn.classList.add("copied");
      showToast("信标已复制到剪贴板");
      setTimeout(() => copyBtn.classList.remove("copied"), 1600);
    });
  }

  /* ── 主题切换（浅 / 深）──
     初始主题由 <head> 内联脚本设定（避免首帧闪白）；这里只负责按钮与后续切换。 */
  const themeBtn = document.getElementById("themeToggle");
  if (themeBtn) {
    const syncTheme = () => {
      const dark = document.documentElement.getAttribute("data-theme") === "dark";
      themeBtn.setAttribute("aria-pressed", String(dark));
      const label = dark
        ? themeBtn.dataset.labelDark || "Switch to light mode"
        : themeBtn.dataset.labelLight || "Switch to dark mode";
      themeBtn.setAttribute("aria-label", label);
      themeBtn.setAttribute("title", label);
      const icon = themeBtn.querySelector("i");
      if (icon) icon.className = dark ? "fa-solid fa-sun" : "fa-solid fa-moon";
    };
    syncTheme();
    themeBtn.addEventListener("click", () => {
      const next =
        document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark";
      document.documentElement.setAttribute("data-theme", next);
      try { localStorage.setItem("theme", next); } catch (e) {}
      const meta = document.querySelector('meta[name="theme-color"]');
      if (meta) meta.setAttribute("content", next === "dark" ? "#0b1220" : "#f3f6fd");
      syncTheme();
    });
  }

  /* ── 页脚年份自动更新 ── */
  const yr = document.getElementById("year");
  if (yr) yr.textContent = new Date().getFullYear();

  /* ── 滚动显现动画 ── */
  const revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !prefersReduced) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    revealEls.forEach((el) => {
      const idx = el.dataset.delay | 0;
      el.classList.add("d" + idx);
      io.observe(el);
    });
  } else {
    revealEls.forEach((el) => el.classList.add("in"));
  }

  /* ── Hero 粒子背景（APRS 星网/雷达网络感） ──
     子页（如帮助中心）没有 hero 画布：canvas 为 null 时下面的 if 守卫会跳过动画，
     但 ctx 取值必须空值安全 —— 否则 `null.getContext` 会抛错，
     把后面的版本号刷新与赞助渲染一并打断（IIFE 内无 try 包裹）。 */
  const canvas = document.getElementById("heroCanvas");
  const ctx = canvas ? canvas.getContext("2d") : null;
  let w = 0, h = 0, particles = [], rafId = null;

  function resize() {
    w = canvas.width = canvas.offsetWidth * devicePixelRatio;
    h = canvas.height = canvas.offsetHeight * devicePixelRatio;
    seed();
  }

  function seed() {
    const count = Math.min(90, Math.floor((w * h) / 26000));
    particles = Array.from({ length: count }, () => ({
      x: Math.random() * w,
      y: Math.random() * h,
      vx: (Math.random() - 0.5) * 0.35 * devicePixelRatio,
      vy: (Math.random() - 0.5) * 0.35 * devicePixelRatio,
      r: (Math.random() * 1.6 + 0.6) * devicePixelRatio,
    }));
  }

  function draw() {
    ctx.clearRect(0, 0, w, h);
    const maxDist = 150 * devicePixelRatio;
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0 || p.x > w) p.vx *= -1;
      if (p.y < 0 || p.y > h) p.vy *= -1;

      for (let j = i + 1; j < particles.length; j++) {
        const q = particles[j];
        const dx = p.x - q.x, dy = p.y - q.y;
        const d2 = dx * dx + dy * dy;
        if (d2 < maxDist * maxDist) {
          const a = (1 - Math.sqrt(d2) / maxDist) * 0.5;
          ctx.strokeStyle = `rgba(14, 165, 233, ${a * 0.3})`;
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(p.x, p.y);
          ctx.lineTo(q.x, q.y);
          ctx.stroke();
        }
      }
      const glow = 0.4 + Math.sin(performance.now() / 1200 + i) * 0.3;
      ctx.fillStyle = `rgba(56, 189, 248, ${glow * 0.7})`;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fill();
    }
    rafId = requestAnimationFrame(draw);
  }

  if (canvas && !prefersReduced) {
    resize();
    window.addEventListener("resize", resize, { passive: true });
    draw();
  } else if (canvas) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
  }

  /* ── 手机模拟器：地图 / 聊天切换（悬停已支持，滚动到视口时更明显） ── */
  const phone = document.querySelector(".hero-phone");
  if (phone && "IntersectionObserver" in window) {
    const pio = new IntersectionObserver((es) => {
      es.forEach((e) => {
        if (e.isIntersecting) {
          phone.classList.add("in-view");
          pio.unobserve(phone);
        }
      });
    });
    pio.observe(phone);
  }

  /* ── 自动拉取 GitHub 最新版本号，替换页面上的静态版本（下载按钮 / Hero 徽章） ── */
  const refreshVersion = (() => {
    const els = [
      document.querySelector(".nav-cta"),
      document.querySelector(".hero-badge"),
    ].filter(Boolean);
    if (!els.length) return;
    // 各语言页显示版本号文本形如 "v1.6.18"/"下载 v1.6.18"，只替换版本部分
    const versionRe = /v\d+\.\d+\.\d+/;
    const update = (ver) => {
      els.forEach((el) => {
        const txt = el.textContent || "";
        if (versionRe.test(txt)) {
          el.textContent = txt.replace(versionRe, ver);
        }
      });
    };
    // 先尝试 GitHub API（可能限流/失败），失败则静默保留静态版本
    fetch("https://api.github.com/repos/dariondong/APRSLocus/releases/latest", {
      headers: { Accept: "application/vnd.github+json" },
    })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => {
        const tag = (data && data.tag_name) || "";
        const m = tag.match(/v?(\d+\.\d+\.\d+)/);
        if (m) update("v" + m[1]);
      })
      .catch(() => {});
  })();

  /* ── 赞助名单：直接读 /sponsors.json ──

     为什么动态渲染：这份名单原先在三个语言页里各手写一份，于是必然走样 ——
     实际就漏了 STUDENT HAMS 群组、BG7PGW（咖啡）与「每一位支持者」。
     现在以 sponsors.json 为唯一真源（App 内的「赞助与鸣谢」页读的也是它），
     以后加赞助人只改那一个文件，官网自动跟上。

     静态 HTML 里保留同一份名单作为兜底（JS 被禁用或取不到数据时照常显示）。 */
  const renderSponsors = (() => {
    const box = document.getElementById("sponsorList");
    if (!box) return;
    const lang = box.getAttribute("data-lang") || "zh";

    // 按赞助类型给头像底色（与页面既有渐变风格一致）
    const GRAD = {
      group: "linear-gradient(135deg,#6366f1,#4338ca)",
      coffee: "linear-gradient(135deg,#f59e0b,#b45309)",
      jade: "linear-gradient(135deg,#c9a227,#8a6d1f)",
      school: "linear-gradient(135deg,#0ea5b7,#0b7285)",
      api: "linear-gradient(135deg,#0891b2,#164e63)",
      everyone: "linear-gradient(135deg,#ec4899,#be185d)",
    };

    // 头像里那个字：呼号取「地区号后面的字母」（BG7ORC → O），其余取首字。
    // 用 Array.from 而不是 [0]，避免把 emoji / 代理对切成半个字符。
    const initial = (name) => {
      const m = /^[A-Za-z]{1,2}\d([A-Za-z])/.exec(name || "");
      if (m) return m[1].toUpperCase();
      return Array.from(String(name || "").trim())[0] || "·";
    };

    const esc = (v) =>
      String(v == null ? "" : v).replace(/[&<>"]/g, (c) =>
        ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])
      );

    // 语言回落：该语言 → **中文基准**（不带英文）→ 英文。
    // 顺序刻意如此：sponsors.json 里 `desc` 本身就是中文基准，若把英文插在它前面，
    // 中文页会因为条目没写 `zh` 键而显示英文。
    const pick = (map, base) =>
      (map && map[lang]) || base || (map && map.en) || "";

    // 绝对路径：/zh-TW/ 与 /en/ 下用相对路径会取不到
    fetch("/sponsors.json", { cache: "no-cache" })
      .then((r) => (r.ok ? r.json() : Promise.reject(r.status)))
      .then((data) => {
        const list = data && data.sponsors;
        if (!Array.isArray(list) || !list.length) return;
        box.innerHTML = list
          .map((sp) => {
            const name = pick(sp.names, sp.name);
            const desc = pick(sp.descs, sp.desc);
            const grad = GRAD[sp.kind] || GRAD.everyone;
            return (
              '<span class="contributor">' +
              '<span class="avatar" style="background:' + grad + '">' +
              esc(initial(name)) + "</span>" +
              '<span><span class="c-name">' + esc(name) +
              '</span><span class="c-role">' + esc(desc) + "</span></span>" +
              "</span>"
            );
          })
          .join("");
      })
      .catch(() => {});
  })();

})();
