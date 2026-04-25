/* ══════════════════════════════════════════════════════════════
   BOOT — runs after every other script has loaded.
══════════════════════════════════════════════════════════════ */
(function boot(){
  // initial lang — URL param wins so /?lang=ar works for hreflang and
  // direct shares; falls back to localStorage, then English.
  let lang = 'en';
  const urlLang = new URLSearchParams(location.search).get('lang');
  if (urlLang === 'ar' || urlLang === 'en') {
    lang = urlLang;
  } else {
    try { lang = localStorage.getItem('manfath.lang') || 'en'; } catch (e) {}
  }
  applyLang(lang);

  // paint threads + tunnel demo (depend on layout)
  drawStackThreads();
  drawTunnelDemo();

  // pull live repo stats — non-blocking; falls back to defaults on error.
  fetchRepoStats();
})();
