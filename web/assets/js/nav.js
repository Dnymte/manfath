/* ───────── nav scroll state ───────── */
const nav = document.getElementById('nav');
window.addEventListener('scroll', ()=>{
  nav.classList.toggle('scrolled', window.scrollY > 4);
}, {passive:true});

/* ───────── reveal-on-scroll ───────── */
const io = new IntersectionObserver(entries=>{
  entries.forEach(e=>{ if(e.isIntersecting){ e.target.classList.add('in'); io.unobserve(e.target); }});
},{threshold:.12});
document.querySelectorAll('.reveal').forEach(el=>io.observe(el));
