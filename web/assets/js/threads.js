/* ══════════════════════════════════════════════════════════════
   STACK THREADS DIAGRAM
══════════════════════════════════════════════════════════════ */
const STACK_NODES = [
  {label:"next.js",      port:"3000"},
  {label:"postgres",     port:"5432"},
  {label:"redis",        port:"6379"},
  {label:"rails",        port:"3001"},
  {label:"django",       port:"8000"},
  {label:"phoenix",      port:"4000"},
  {label:"vite",         port:"5173"},
  {label:"express",      port:"3333"},
  {label:"nginx",        port:"8080"},
  {label:"elastic",      port:"9200"},
];

function drawStackThreads(){
  const svg = document.getElementById('stackSvg');
  if(!svg) return;
  svg.innerHTML = `
    <defs>
      <radialGradient id="coreGlow2" cx=".5" cy=".5" r=".5">
        <stop offset="0" stop-color="#b8ff5c" stop-opacity=".55"/>
        <stop offset="1" stop-color="#b8ff5c" stop-opacity="0"/>
      </radialGradient>
      <filter id="threadGlow2" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="1.2" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id="packetGlow2" x="-200%" y="-200%" width="500%" height="500%">
        <feGaussianBlur stdDeviation="2.4" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
    </defs>
  `;
  const cx = 600, cy = 230;
  // core glow + node
  const glow = document.createElementNS('http://www.w3.org/2000/svg','circle');
  glow.setAttribute('cx', cx); glow.setAttribute('cy', cy);
  glow.setAttribute('r', 90); glow.setAttribute('fill','url(#coreGlow2)');
  svg.appendChild(glow);

  // center "manfath" chip (mini port illustration)
  const chip = document.createElementNS('http://www.w3.org/2000/svg','g');
  chip.setAttribute('transform', `translate(${cx} ${cy})`);
  chip.innerHTML = `
    <rect x="-52" y="-22" width="104" height="44" rx="5" fill="#e8e2d4"/>
    <rect x="-40" y="-12" width="80" height="24" rx="2" fill="#0a0a0c"/>
    <g fill="#d9b26a">
      <rect x="-36" y="-8" width="1.6" height="16"/>
      <rect x="-28" y="-8" width="1.6" height="16"/>
      <rect x="-20" y="-8" width="1.6" height="16"/>
      <rect x="-12" y="-8" width="1.6" height="16"/>
      <rect x="-4"  y="-8" width="1.6" height="16"/>
      <rect x="4"   y="-8" width="1.6" height="16"/>
      <rect x="12"  y="-8" width="1.6" height="16"/>
      <rect x="20"  y="-8" width="1.6" height="16"/>
      <rect x="28"  y="-8" width="1.6" height="16"/>
      <rect x="36"  y="-8" width="1.6" height="16"/>
    </g>
    <circle cx="-44" cy="-16" r="2" fill="#b8ff5c"/>
    <text x="0" y="40" font-family="Inter Tight, sans-serif" font-size="13" font-weight="700" fill="#e8e4da" text-anchor="middle" letter-spacing="-.01em">Manfath</text>
  `;
  svg.appendChild(chip);

  // Three passes so the z-order is predictable:
  //   1. all paths (threads)         — bottom
  //   2. all packets (cyan dots)     — middle
  //   3. all node chips + labels     — top
  // The previous code interleaved them per-node, which meant later
  // paths drew over earlier port chips.
  const N = STACK_NODES.length;
  const positions = STACK_NODES.map((n, i)=>{
    const a = (i/N)*Math.PI*2 - Math.PI/2;
    const r = 180;
    return { node: n, i,
      x: cx + Math.cos(a)*r,
      y: cy + Math.sin(a)*r*.85
    };
  });

  // PASS 1 — paths
  positions.forEach(({i, x, y})=>{
    const midOff = 30 * (i%2===0 ? 1 : -1);
    const p = document.createElementNS('http://www.w3.org/2000/svg','path');
    const d = `M ${cx} ${cy} Q ${(cx+x)/2 + midOff} ${(cy+y)/2 + midOff} ${x} ${y}`;
    p.setAttribute('d', d);
    p.setAttribute('stroke','rgba(184,255,92,.5)');
    p.setAttribute('stroke-width','1.1');
    p.setAttribute('fill','none');
    p.setAttribute('filter','url(#threadGlow2)');
    p.setAttribute('id', `stackPath-${i}`);
    const L = 600;
    p.style.strokeDasharray = L;
    p.style.strokeDashoffset = L;
    p.style.transition = 'stroke-dashoffset 1.2s cubic-bezier(.2,.8,.2,1)';
    p.style.transitionDelay = (i*.07)+'s';
    svg.appendChild(p);
    setTimeout(()=>{ p.style.strokeDashoffset = 0; }, 200);
  });

  // PASS 2 — animated packets (above paths, below nodes)
  positions.forEach(({i})=>{
    const packet = document.createElementNS('http://www.w3.org/2000/svg','circle');
    packet.setAttribute('r', '2.2');
    packet.setAttribute('fill','#5ce4ff');
    packet.setAttribute('filter','url(#packetGlow2)');
    const anim = document.createElementNS('http://www.w3.org/2000/svg','animateMotion');
    anim.setAttribute('dur', (2 + Math.random()*2.5) + 's');
    anim.setAttribute('repeatCount','indefinite');
    anim.setAttribute('begin', (i*.2 + Math.random()) + 's');
    const mp = document.createElementNS('http://www.w3.org/2000/svg','mpath');
    mp.setAttributeNS('http://www.w3.org/1999/xlink','xlink:href', `#stackPath-${i}`);
    anim.appendChild(mp);
    packet.appendChild(anim);
    svg.appendChild(packet);
  });

  // PASS 3 — node chips on top of everything
  positions.forEach(({node, x, y})=>{
    const g = document.createElementNS('http://www.w3.org/2000/svg','g');
    g.setAttribute('transform', `translate(${x} ${y})`);
    g.innerHTML = `
      <circle r="11" fill="#0a0a0c"/>
      <circle r="4" fill="#b8ff5c"/>
      <circle r="9" fill="none" stroke="rgba(184,255,92,.25)" stroke-width=".8"/>
      <text x="0" y="-16" font-family="JetBrains Mono, monospace" font-size="10" fill="#5a564e" text-anchor="middle">:${node.port}</text>
      <text x="0" y="26" font-family="Inter Tight, sans-serif" font-size="13" font-weight="500" fill="#e8e4da" text-anchor="middle">${node.label}</text>
    `;
    svg.appendChild(g);
  });
}

