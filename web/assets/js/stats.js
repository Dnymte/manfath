/* ══════════════════════════════════════════════════════════════
   GITHUB STATS — pulls stargazers / contributors / latest release
══════════════════════════════════════════════════════════════ */
const REPO = 'Dnymte/manfath';

function formatStars(n){
  if (n >= 10000) return (n/1000).toFixed(1).replace(/\.0$/,'') + 'k';
  if (n >= 1000)  return (n/1000).toFixed(1) + 'k';
  return String(n);
}

async function fetchRepoStats(){
  // Star count + repo metadata
  fetch('https://api.github.com/repos/' + REPO).then(r => r.ok ? r.json() : null).then(data => {
    if (!data) return;
    if (typeof data.stargazers_count === 'number') {
      const el = document.getElementById('ghStars');
      if (el) el.textContent = formatStars(data.stargazers_count);
    }
  }).catch(()=>{});

  // Contributors — per_page=1 gives us a Link header with rel="last"
  // whose page number == total contributors. Anonymous excluded by default.
  fetch('https://api.github.com/repos/' + REPO + '/contributors?per_page=1&anon=false')
    .then(r => {
      if (!r.ok) return null;
      const link = r.headers.get('link') || '';
      const m = link.match(/&page=(\d+)>; rel="last"/);
      if (m) return parseInt(m[1], 10);
      return r.json().then(arr => Array.isArray(arr) ? arr.length : null);
    })
    .then(count => {
      const el = document.getElementById('ghContributors');
      if (el && typeof count === 'number') el.textContent = String(count);
    }).catch(()=>{});

  // Latest release tag
  fetch('https://api.github.com/repos/' + REPO + '/releases/latest')
    .then(r => r.ok ? r.json() : null)
    .then(data => {
      if (!data || !data.tag_name) return;
      const el = document.getElementById('ghVersion');
      if (el) el.textContent = data.tag_name.replace(/^v/, '');
    }).catch(()=>{});
}
