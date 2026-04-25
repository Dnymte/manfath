/* ══════════════════════════════════════════════════════════════
   BOOT — runs after every other script has loaded.
══════════════════════════════════════════════════════════════ */
(function boot(){
  // initial lang
  let lang = 'en';
  try { lang = localStorage.getItem('manfath.lang') || 'en'; } catch (e) {}
  applyLang(lang);

  // paint threads + tunnel demo (depend on layout)
  drawStackThreads();
  drawTunnelDemo();

  // pull live repo stats — non-blocking; falls back to defaults on error.
  fetchRepoStats();
})();
