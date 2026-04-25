/* ══════════════════════════════════════════════════════════════
   TUNNEL DEMO LOOP
══════════════════════════════════════════════════════════════ */
function drawTunnelDemo(){
  const svg = document.getElementById('tunnelSvg');
  if(!svg) return;
  const isRTL = document.documentElement.dir === 'rtl';
  svg.innerHTML = `
    <defs>
      <filter id="tunGlow" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="1.6" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id="tunPkt" x="-200%" y="-200%" width="500%" height="500%">
        <feGaussianBlur stdDeviation="2.4" result="b"/>
        <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <linearGradient id="tunThread" x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stop-color="#b8ff5c" stop-opacity=".8"/>
        <stop offset=".55" stop-color="#b8ff5c" stop-opacity=".4"/>
        <stop offset="1" stop-color="#5ce4ff" stop-opacity=".8"/>
      </linearGradient>
    </defs>
  `;
  const W = 1200, H = 260;
  const originX = isRTL ? W - 80 : 80;
  const destX   = isRTL ? 80 : W - 80;
  const midY = 130;

  // local box (the machine / port chip)
  const box = document.createElementNS('http://www.w3.org/2000/svg','g');
  box.setAttribute('transform', `translate(${originX} ${midY})`);
  box.innerHTML = `
    <rect x="-36" y="-20" width="72" height="40" rx="4" fill="#e8e2d4"/>
    <rect x="-28" y="-12" width="56" height="24" rx="2" fill="#0a0a0c"/>
    <g fill="#d9b26a">
      <rect x="-24" y="-8" width="1.4" height="16"/>
      <rect x="-18" y="-8" width="1.4" height="16"/>
      <rect x="-12" y="-8" width="1.4" height="16"/>
      <rect x="-6"  y="-8" width="1.4" height="16"/>
      <rect x="0"   y="-8" width="1.4" height="16"/>
      <rect x="6"   y="-8" width="1.4" height="16"/>
      <rect x="12"  y="-8" width="1.4" height="16"/>
      <rect x="18"  y="-8" width="1.4" height="16"/>
    </g>
    <circle cx="-30" cy="-15" r="1.6" fill="#b8ff5c"/>
    <text x="0" y="38" font-family="JetBrains Mono, monospace" font-size="11" fill="#5a564e" text-anchor="middle">:3000 localhost</text>
  `;
  svg.appendChild(box);

  // cloud/globe on the far side
  const cloud = document.createElementNS('http://www.w3.org/2000/svg','g');
  cloud.setAttribute('transform', `translate(${destX} ${midY})`);
  cloud.innerHTML = `
    <circle r="24" fill="none" stroke="#5ce4ff" stroke-width="1" opacity=".8"/>
    <circle r="32" fill="none" stroke="#5ce4ff" stroke-width=".6" opacity=".4"/>
    <circle r="14" fill="rgba(92,228,255,.12)" stroke="#5ce4ff" stroke-width=".8"/>
    <path d="M -12 0 L 12 0 M 0 -12 L 0 12" stroke="#5ce4ff" stroke-width=".6" opacity=".6"/>
    <ellipse rx="12" ry="4" fill="none" stroke="#5ce4ff" stroke-width=".6" opacity=".6"/>
    <text x="0" y="48" font-family="JetBrains Mono, monospace" font-size="11" fill="#5a564e" text-anchor="middle">public URL</text>
  `;
  svg.appendChild(cloud);

  // curved thread
  const sign = isRTL ? -1 : 1;
  const d = `M ${originX + 40*sign} ${midY} C ${originX + 260*sign} ${midY - 90}, ${destX - 260*sign} ${midY + 90}, ${destX - 40*sign} ${midY}`;
  const thread = document.createElementNS('http://www.w3.org/2000/svg','path');
  thread.setAttribute('d', d);
  thread.setAttribute('stroke','url(#tunThread)');
  thread.setAttribute('stroke-width','1.4');
  thread.setAttribute('fill','none');
  thread.setAttribute('filter','url(#tunGlow)');
  thread.setAttribute('id','tunPath');
  const L = 1400;
  thread.style.strokeDasharray = L;
  thread.style.strokeDashoffset = L;
  thread.style.transition = 'stroke-dashoffset 1.4s cubic-bezier(.2,.8,.2,1)';
  svg.appendChild(thread);

  // packets bouncing along
  for(let i=0;i<3;i++){
    const pk = document.createElementNS('http://www.w3.org/2000/svg','circle');
    pk.setAttribute('r','2.8');
    pk.setAttribute('fill','#5ce4ff');
    pk.setAttribute('filter','url(#tunPkt)');
    const am = document.createElementNS('http://www.w3.org/2000/svg','animateMotion');
    am.setAttribute('dur','3.2s');
    am.setAttribute('repeatCount','indefinite');
    am.setAttribute('begin', (i*1 + 1.6) + 's');
    const mp = document.createElementNS('http://www.w3.org/2000/svg','mpath');
    mp.setAttributeNS('http://www.w3.org/1999/xlink','xlink:href','#tunPath');
    am.appendChild(mp);
    pk.appendChild(am);
    svg.appendChild(pk);
  }

  // trigger loop: once thread is in viewport, draw it + fire toast every ~5s
  const toast = document.getElementById('tunnelToast');
  const container = svg.parentElement;
  const ioT = new IntersectionObserver(entries=>{
    entries.forEach(e=>{
      if(e.isIntersecting){
        thread.style.strokeDashoffset = 0;
        // periodic toast
        const loop = ()=>{
          toast.classList.add('in');
          setTimeout(()=>toast.classList.remove('in'), 2200);
        };
        setTimeout(loop, 1400);
        setInterval(loop, 5000);
        ioT.disconnect();
      }
    });
  }, {threshold:.3});
  ioT.observe(container);
}

