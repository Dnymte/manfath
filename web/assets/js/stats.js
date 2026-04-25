/* ══════════════════════════════════════════════════════════════
   GITHUB STATS — pulls stargazers / contributors / latest release.

   Unauthenticated GitHub REST is capped at 60 req/h per IP, so we
   cache each value in localStorage for an hour. A reload within
   the TTL skips the network entirely; a stale cache or a 403 (rate
   limit) falls back silently to whatever was last shown.
══════════════════════════════════════════════════════════════ */
const REPO = 'Dnymte/manfath';
const CACHE_TTL_MS = 60 * 60 * 1000;          // 1 hour
const CACHE_KEY    = 'manfath.stats.v1';

function formatStars(n){
  if (n >= 10000) return (n/1000).toFixed(1).replace(/\.0$/,'') + 'k';
  if (n >= 1000)  return (n/1000).toFixed(1) + 'k';
  return String(n);
}

function readCache(){
  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    const obj = JSON.parse(raw);
    if (!obj || typeof obj.t !== 'number') return null;
    if (Date.now() - obj.t > CACHE_TTL_MS) return obj;   // stale but usable
    return obj;
  } catch (e) { return null; }
}

function writeCache(patch){
  try {
    const cur = readCache() || {};
    const next = Object.assign({}, cur, patch, { t: Date.now() });
    localStorage.setItem(CACHE_KEY, JSON.stringify(next));
  } catch (e) {}
}

function paint(stars, contributors, version){
  if (typeof stars === 'number') {
    const el = document.getElementById('ghStars');
    if (el) el.textContent = formatStars(stars);
  }
  if (typeof contributors === 'number') {
    const el = document.getElementById('ghContributors');
    if (el) el.textContent = String(contributors);
  }
  if (typeof version === 'string' && version) {
    const el = document.getElementById('ghVersion');
    if (el) el.textContent = version.replace(/^v/, '');
  }
}

async function fetchRepoStats(){
  // 1. Paint cached values immediately (even if stale) so the UI
  //    shows numbers before any network call resolves.
  const cached = readCache();
  if (cached) paint(cached.stars, cached.contributors, cached.version);

  // 2. If the cache is fresh, skip all network. This is the common
  //    path for repeat visitors and is what keeps us under 60/h.
  if (cached && Date.now() - cached.t <= CACHE_TTL_MS) return;

  // 3. Refresh in the background. Each request fails silently on
  //    403 / network error — the previously-cached value stays put.
  fetch('https://api.github.com/repos/' + REPO).then(r => r.ok ? r.json() : null).then(data => {
    if (!data || typeof data.stargazers_count !== 'number') return;
    paint(data.stargazers_count, undefined, undefined);
    writeCache({ stars: data.stargazers_count });
  }).catch(()=>{});

  fetch('https://api.github.com/repos/' + REPO + '/contributors?per_page=1&anon=false')
    .then(r => {
      if (!r.ok) return null;
      // per_page=1 gives a Link header whose rel="last" page == total.
      const link = r.headers.get('link') || '';
      const m = link.match(/[?&]page=(\d+)>;\s*rel="last"/);
      if (m) return parseInt(m[1], 10);
      return r.json().then(arr => Array.isArray(arr) ? arr.length : null);
    })
    .then(count => {
      if (typeof count !== 'number') return;
      paint(undefined, count, undefined);
      writeCache({ contributors: count });
    }).catch(()=>{});

  fetch('https://api.github.com/repos/' + REPO + '/releases/latest')
    .then(r => r.ok ? r.json() : null)
    .then(data => {
      if (!data || !data.tag_name) return;
      paint(undefined, undefined, data.tag_name);
      writeCache({ version: data.tag_name });
    }).catch(()=>{});
}
