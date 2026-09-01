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

  burger.addEventListener("click", () => {
    burger.classList.toggle("open");
    navLinks.classList.toggle("open");
    document.body.style.overflow = navLinks.classList.contains("open") ? "hidden" : "";
  });
  navLinks.querySelectorAll("a").forEach((a) =>
    a.addEventListener("click", () => {
      burger.classList.remove("open");
      navLinks.classList.remove("open");
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

  /* ── Hero 粒子背景（APRS 星网/雷达网络感） ── */
  const canvas = document.getElementById("heroCanvas");
  const ctx = canvas.getContext("2d");
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
})();
