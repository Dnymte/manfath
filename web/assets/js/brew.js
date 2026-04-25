/* ══════════════════════════════════════════════════════════════
   BREW COPY
══════════════════════════════════════════════════════════════ */
document.getElementById('brewCopy').addEventListener('click', ()=>{
  const btn = document.getElementById('brewCopy');
  const orig = btn.textContent;
  try{
    navigator.clipboard && navigator.clipboard.writeText('brew install --cask Dnymte/tap/manfath');
  }catch(e){}
  btn.textContent = '✓ COPIED';
  setTimeout(()=>{ btn.textContent = orig; }, 1500);
});
