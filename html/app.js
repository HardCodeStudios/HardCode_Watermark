function formatNum(n) {
  if (n === null || n === undefined) return "--";
  try { return Number(n).toLocaleString(); } catch (_) { return String(n); }
}

function formatAmountHTML(input) {
  try {
    if (input === null || input === undefined) return '<span class="whole">--</span>';
    let s = String(input).trim().replace(/\s+/g, "").replace(/[,']/g, "");
    let n = Number(s);
    if (!isFinite(n)) return `<span class="whole">${s}</span>`;
    n = Math.round(n * 100) / 100;
    const neg = n < 0 ? "-" : "";
    n = Math.abs(n);
    let [whole, frac] = n.toFixed(2).split(".");
    whole = String(whole).replace(/^0+(?=\d)/, "");
    frac = (frac || "").replace(/0+$/, "");
    const wholeHTML = `<span class="whole">${neg}${whole}</span>`;
    const fracHTML  = frac.length ? `<span class="cents">.${frac}</span>` : "";
    return wholeHTML + fracHTML;
  } catch {
    return '<span class="whole">--</span>';
  }
}

function syncBarsToText() {
  const m = document.getElementById('stat-money');
  const g = document.getElementById('stat-gold');
  if (m) {
    const w = Math.ceil(m.getBoundingClientRect().width);
    m.style.setProperty('--money-width', w + 'px');
  }
  if (g) {
    const w = Math.ceil(g.getBoundingClientRect().width);
    g.style.setProperty('--gold-width', w + 'px');
  }
}

function scheduleSyncBars() {
  requestAnimationFrame(() => requestAnimationFrame(syncBarsToText));
}

(function initUiScale(){
  const BASE_W = 1920;
  const BASE_H = 1080;
  const MIN_S  = 0.70;
  const MAX_S  = 2.00;
  function applyScale(){
    const w = window.innerWidth;
    const h = window.innerHeight;
    const s = Math.min(w/BASE_W, h/BASE_H);
    const clamped = Math.max(MIN_S, Math.min(MAX_S, s));
    document.documentElement.style.setProperty('--ui-scale', clamped);
    scheduleSyncBars();
  }
  let t = null;
  window.addEventListener('resize', () => { if (t) clearTimeout(t); t = setTimeout(applyScale, 120); });
  applyScale();
})();

(function initRealClock(){
  function pad(n){ return String(n).padStart(2,"0"); }
  function tick(){
    const now = new Date();
    const dd = pad(now.getDate());
    const mm = pad(now.getMonth()+1);
    const yyyy = now.getFullYear();
    const hh = pad(now.getHours());
    const mi = pad(now.getMinutes());
    const elDate = document.getElementById('real-date');
    const elTime = document.getElementById('real-time');
    if (elDate) elDate.textContent = `${dd}/${mm}/${yyyy}`;
    if (elTime) elTime.textContent = `${hh}:${mi}`;
  }
  tick();
  setInterval(tick, 1000);
})();

window.addEventListener('message', function (e) {
  const data = e.data || {};
  const container = document.getElementById('container');
  if (data.type === 'DisplayWM') {
    if (data.visible === true) {
      const position = data.position || 'top-right';
      container.classList.remove("top-right","top-left","bottom-right","bottom-left");
      container.classList.add(position);
      container.style.display = 'flex';
      container.style.opacity = 1;
      if (data.stats) {
        const s = data.stats;
        const elMoney = document.getElementById('stat-money');
        const elGold  = document.getElementById('stat-gold');
        const elId    = document.getElementById('stat-id');
        if (elMoney) elMoney.innerHTML = formatAmountHTML(s.money);
        if (elGold)  elGold.innerHTML  = formatAmountHTML(s.gold);
        if (elId)    elId.textContent  = (s.displayId ?? "--");
        scheduleSyncBars();
      }
    } else {
      container.style.opacity = 0;
      setTimeout(()=>{ container.style.display = 'none'; }, 200);
    }
    return;
  }

  if (data.type === 'SetWMPosition') {
    const position = data.position || 'top-right';
    container.classList.remove("top-right","top-left","bottom-right","bottom-left");
    container.classList.add(position);
    scheduleSyncBars();
    return;
  }

  if (data.type === 'SetStats') {
    const elMoney = document.getElementById('stat-money');
    const elGold  = document.getElementById('stat-gold');
    const elId    = document.getElementById('stat-id');
    if (elMoney) elMoney.innerHTML = formatAmountHTML(data.money);
    if (elGold)  elGold.innerHTML  = formatAmountHTML(data.gold);
    if (elId)    elId.textContent  = (data.displayId ?? "--");
    scheduleSyncBars();
    return;
  }

  if (data.type === 'SetClock') {
    if (typeof data.gameTime === 'string') {
      const elGT = document.getElementById('game-time');
      if (elGT) elGT.textContent = data.gameTime;
    }
    return;
  }

  if (data.type === 'ToggleClock') {
    const hud = document.getElementById('hud-clock');
    if (hud) hud.classList.toggle('hidden', data.visible === false);
    return;
  }
});

window.addEventListener('resize', scheduleSyncBars);