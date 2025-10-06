function formatNum(n) {
  if (n === null || n === undefined) return "--";
  try { return Number(n).toLocaleString(); } catch (_) { return String(n); }
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
    document.getElementById('real-date').textContent = `${dd}/${mm}/${yyyy}`;
    document.getElementById('real-time').textContent = `${hh}:${mi}`;
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
        document.getElementById('stat-money').textContent = formatNum(s.money);
        document.getElementById('stat-gold').textContent  = formatNum(s.gold);
        document.getElementById('stat-id').textContent    = (s.displayId ?? "--");
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
    return;
  }

  if (data.type === 'SetStats') {
    document.getElementById('stat-money').textContent = formatNum(data.money);
    document.getElementById('stat-gold').textContent  = formatNum(data.gold);
    document.getElementById('stat-id').textContent    = (data.displayId ?? "--");
    return;
  }

  if (data.type === 'SetClock') {
    if (typeof data.gameTime === 'string') document.getElementById('game-time').textContent = data.gameTime;
    return;
  }

  if (data.type === 'ToggleClock') {
    const hud = document.getElementById('hud-clock');
    hud.classList.toggle('hidden', data.visible === false);
    return;
  }
});