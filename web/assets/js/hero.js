/* ══════════════════════════════════════════════════════════════
   HERO CONTROLLER
   - Plug slides in from right (LTR) or left (RTL)
   - Slight overshoot + bounce on connection
   - LED lights up
   - Threads fan outward from port, each to a labeled node
   - Packets travel along threads
   - Ambient sway + cursor-magnet on control points
══════════════════════════════════════════════════════════════ */
const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const HERO_NODES = [
  {port:"3000",  label:"next dev"},
  {port:"5432",  label:"postgres"},
  {port:"8080",  label:"nginx"},
  {port:"6379",  label:"redis"},
  {port:"4000",  label:"phoenix"},
  {port:"5173",  label:"vite"},
  {port:"27017", label:"mongod"},
  {port:"9200",  label:"elastic"},
  {port:"11434", label:"ollama"},
  {port:"1313",  label:"hugo"},
];

const heroController = (()=>{
  const svg        = document.getElementById('heroSvg');
  const threadsG   = document.getElementById('threads');
  const labelsG    = document.getElementById('nodeLabels');
  const packetsG   = document.getElementById('packets');
  const outlet     = document.getElementById('outlet');
  const laptop     = document.getElementById('laptop');
  const laptopPortR= document.getElementById('laptopPort');
  const laptopPortL= document.getElementById('laptopPortLeft');
  const laptopLedR = document.getElementById('laptopLed');
  const laptopLedL = document.getElementById('laptopLedLeft');
  const wallLed    = document.getElementById('wallLed');

  const plug       = document.getElementById('plug');
  const cablePath  = document.getElementById('cablePath');
  const cableHi    = document.getElementById('cableHighlight');

  const VB = {w:1400, h:800};
  // scene anchors — reassigned per direction
  // LTR: outlet on the RIGHT, laptop CENTER-LEFT
  // RTL: outlet on the LEFT,  laptop CENTER-RIGHT
  const SCENE = {
    // LTR: outlet on LEFT wall at (180,280). Laptop center-right at (870,540). Left port at world (570,630).
    // Cable enters port horizontally from the left, so final tangent should point rightward.
    ltr:{ outletX:180, outletY:280, laptopX:870, laptopY:540, plugStart:{x:180,y:315}, plugEnd:{x:570,y:630}, cableD:'M 180 315 C 220 500, 360 680, 570 630', plugAngleEnd:0 },
    // RTL mirror
    rtl:{ outletX:1220, outletY:280, laptopX:530, laptopY:540, plugStart:{x:1220,y:315}, plugEnd:{x:830,y:630}, cableD:'M 1220 315 C 1180 500, 1040 680, 830 630', plugAngleEnd:180 }
  };

  let dir = 'ltr';
  const threadData = [];
  let rafId = null;
  const pointer = {x:0, y:0, active:false};

  // ─── thread layout: fan UPWARD-LEFT (LTR) or UPWARD-RIGHT (RTL) above the laptop screen ───
  // Hero copy sits upper-right in LTR; threads must stay AWAY from that zone.
  function layoutNodes(){
    const s = SCENE[dir];
    const ox = s.laptopX, oy = s.laptopY - 90; // origin at screen center
    const nodes = HERO_NODES.map((n, i)=>{
      const N = HERO_NODES.length;
      const t = i/(N-1);
      let angle;
      if(dir === 'ltr'){
        // fan across the top-LEFT arc: 200° (left) → 280° (up, slightly right of straight up)
        angle = 200 + t*80;
      } else {
        // RTL: mirror — fan top-RIGHT: 260° → 340°
        angle = 260 + t*80;
      }
      const rad = angle * Math.PI/180;
      const r = 280 + (i%3)*55 + (i%2)*25;
      const x = ox + Math.cos(rad)*r;
      const y = oy + Math.sin(rad)*r*.9;
      return {
        ...n,
        x: Math.max(80, Math.min(VB.w-80, x)),
        y: Math.max(60, Math.min(VB.h-260, y)),
        origin:{x:ox, y:oy}
      };
    });
    return nodes;
  }

  function makePath(o, nx, ny){
    const dx = nx - o.x, dy = ny - o.y;
    const len = Math.hypot(dx,dy);
    const px = -dy/len, py = dx/len;
    const curve = Math.min(len,360)*.3 * (dy < 0 ? 1 : -1);
    const c1 = {x:o.x + dx*.3 + px*curve*.6, y:o.y + dy*.3 + py*curve*.6};
    const c2 = {x:o.x + dx*.7 + px*curve,    y:o.y + dy*.7 + py*curve};
    return {o, c1, c2, end:{x:nx,y:ny}};
  }
  function pathD(p, ox=0, oy=0){
    return `M ${p.o.x} ${p.o.y} C ${p.c1.x+ox} ${p.c1.y+oy}, ${p.c2.x+ox} ${p.c2.y+oy}, ${p.end.x} ${p.end.y}`;
  }

  function buildThreads(){
    threadsG.innerHTML = '';
    labelsG.innerHTML = '';
    packetsG.innerHTML = '';
    threadData.length = 0;
    const nodes = layoutNodes();
    nodes.forEach((n,i)=>{
      const base = makePath(n.origin, n.x, n.y);
      const p = document.createElementNS('http://www.w3.org/2000/svg','path');
      p.setAttribute('d', pathD(base));
      p.setAttribute('stroke','rgba(184,255,92,.55)');
      p.setAttribute('stroke-width','1.2');
      p.setAttribute('fill','none');
      p.setAttribute('stroke-linecap','round');
      p.setAttribute('filter','url(#threadGlow)');
      const L = 1200;
      p.style.strokeDasharray = L;
      p.style.strokeDashoffset = L;
      p.style.transition = 'stroke-dashoffset 1.2s cubic-bezier(.2,.8,.2,1)';
      threadsG.appendChild(p);

      const pg = document.createElementNS('http://www.w3.org/2000/svg','path');
      pg.setAttribute('d', pathD(base));
      pg.setAttribute('stroke','rgba(184,255,92,.12)');
      pg.setAttribute('stroke-width','3');
      pg.setAttribute('fill','none');
      pg.style.strokeDasharray = L;
      pg.style.strokeDashoffset = L;
      pg.style.transition = 'stroke-dashoffset 1.4s cubic-bezier(.2,.8,.2,1)';
      threadsG.appendChild(pg);

      const chip = document.createElementNS('http://www.w3.org/2000/svg','g');
      chip.setAttribute('transform', `translate(${n.x} ${n.y})`);
      chip.style.opacity='0';
      chip.style.transition='opacity .5s ease';
      const dot = document.createElementNS('http://www.w3.org/2000/svg','circle');
      dot.setAttribute('r','3.2');
      dot.setAttribute('fill','#b8ff5c');
      dot.setAttribute('filter','url(#packetGlow)');
      chip.appendChild(dot);
      const ring = document.createElementNS('http://www.w3.org/2000/svg','circle');
      ring.setAttribute('r','7');
      ring.setAttribute('fill','none');
      ring.setAttribute('stroke','rgba(184,255,92,.35)');
      ring.setAttribute('stroke-width','.8');
      chip.appendChild(ring);

      const side = n.x < n.origin.x ? 'right' : 'left';
      const lx = side==='right' ? 12 : -12;
      const anchor = side==='right' ? 'start' : 'end';

      const portText = document.createElementNS('http://www.w3.org/2000/svg','text');
      portText.setAttribute('x',lx);portText.setAttribute('y',-3);
      portText.setAttribute('font-family','JetBrains Mono, monospace');
      portText.setAttribute('font-size','13');
      portText.setAttribute('font-weight','600');
      portText.setAttribute('fill','#b8ff5c');
      portText.setAttribute('text-anchor',anchor);
      portText.textContent = n.port;
      chip.appendChild(portText);

      const proc = document.createElementNS('http://www.w3.org/2000/svg','text');
      proc.setAttribute('x',lx);proc.setAttribute('y',14);
      proc.setAttribute('font-family','JetBrains Mono, monospace');
      proc.setAttribute('font-size','11');
      proc.setAttribute('fill','#9a958a');
      proc.setAttribute('text-anchor',anchor);
      proc.textContent = n.label;
      chip.appendChild(proc);
      labelsG.appendChild(chip);

      const pktPath = document.createElementNS('http://www.w3.org/2000/svg','path');
      pktPath.setAttribute('d', pathD(base));
      pktPath.setAttribute('fill','none');
      pktPath.setAttribute('stroke','none');
      pktPath.setAttribute('id', `pktpath-${i}`);
      packetsG.appendChild(pktPath);

      const packet = document.createElementNS('http://www.w3.org/2000/svg','circle');
      packet.setAttribute('r','2.6');
      packet.setAttribute('fill','#5ce4ff');
      packet.setAttribute('filter','url(#packetGlow)');
      packet.style.opacity='0';
      const anim = document.createElementNS('http://www.w3.org/2000/svg','animateMotion');
      anim.setAttribute('dur',(2.8 + Math.random()*2.5)+'s');
      anim.setAttribute('repeatCount','indefinite');
      anim.setAttribute('begin',(Math.random()*3)+'s');
      const mp = document.createElementNS('http://www.w3.org/2000/svg','mpath');
      mp.setAttributeNS('http://www.w3.org/1999/xlink','xlink:href',`#pktpath-${i}`);
      anim.appendChild(mp);
      packet.appendChild(anim);
      packetsG.appendChild(packet);

      threadData.push({pathEl:p, glowEl:pg, chip, packet, packetPathEl:pktPath, base, node:n, phase:Math.random()*Math.PI*2, freq:.35+Math.random()*.4, amp:5+Math.random()*8});
    });
  }

  function updatePaths(t){
    for(const th of threadData){
      let ox = Math.sin(t*th.freq + th.phase)*th.amp;
      let oy = Math.cos(t*th.freq*1.1 + th.phase*1.3)*th.amp*.7;
      if(pointer.active){
        const mx = (th.base.o.x + th.node.x)/2, my = (th.base.o.y + th.node.y)/2;
        const dx = pointer.x - mx, dy = pointer.y - my, d = Math.hypot(dx,dy), R = 260;
        if(d < R){
          const f = (1 - d/R)*32;
          ox += (dx/Math.max(d,1))*f;
          oy += (dy/Math.max(d,1))*f;
        }
      }
      const d = pathD(th.base, ox, oy);
      th.pathEl.setAttribute('d', d);
      th.glowEl.setAttribute('d', d);
      th.packetPathEl.setAttribute('d', d);
    }
  }
  function startAmbient(){
    if(prefersReduced) return;
    const t0 = performance.now();
    const tick = now => { updatePaths((now-t0)/1000); rafId = requestAnimationFrame(tick); };
    rafId = requestAnimationFrame(tick);
  }

  // ─── cable draw-on + plug tween along path ───
  function sampleCable(t){
    // get point on cablePath at fractional length t (0..1)
    const L = cablePath.getTotalLength();
    const p1 = cablePath.getPointAtLength(L*t);
    const p2 = cablePath.getPointAtLength(Math.min(L, L*t + 1));
    const angle = Math.atan2(p2.y-p1.y, p2.x-p1.x) * 180/Math.PI;
    return {x:p1.x, y:p1.y, angle};
  }

  function positionScene(){
    const s = SCENE[dir];
    outlet.setAttribute('transform', `translate(${s.outletX} ${s.outletY})`);
    laptop.setAttribute('transform', `translate(${s.laptopX} ${s.laptopY})`);
    // laptop-port visibility: LTR cable comes from lower-LEFT → port on left side. RTL → right side.
    laptopPortR.style.display = dir==='rtl' ? 'block' : 'none';
    laptopPortL.style.display = dir==='ltr' ? 'block' : 'none';
    // cable path
    cablePath.setAttribute('d', s.cableD);
    cableHi.setAttribute('d', s.cableD);
    const L = cablePath.getTotalLength();
    cablePath.style.strokeDasharray = L;
    cablePath.style.strokeDashoffset = L;
    cableHi.style.strokeDasharray = L;
    cableHi.style.strokeDashoffset = L;
  }

  function playPlugIn(){
    const s = SCENE[dir];
    const L = cablePath.getTotalLength();

    if(prefersReduced){
      cablePath.style.strokeDashoffset = 0;
      cableHi.style.strokeDashoffset = 0;
      plug.setAttribute('transform', `translate(${s.plugEnd.x} ${s.plugEnd.y}) rotate(${s.plugAngleEnd})`);
      plug.style.opacity = '1';
      wallLed.style.opacity = '1';
      if(dir==='ltr') laptopLedL.style.opacity='1'; else laptopLedR.style.opacity='1';
      threadData.forEach(th=>{
        th.pathEl.style.strokeDashoffset = 0;
        th.glowEl.style.strokeDashoffset = 0;
        th.chip.style.opacity='1';
        th.packet.style.opacity='.9';
      });
      document.getElementById('heroCopy').classList.add('in');
      return;
    }

    // Phase 1: wall LED pulse + cable draws on (simultaneous w/ plug riding the tip)
    setTimeout(()=>{ wallLed.style.transition='opacity .2s'; wallLed.style.opacity='1'; }, 150);

    // plug appears at start
    plug.style.opacity = '1';

    const DRAW_DUR = 1600;
    const t0 = performance.now();
    const ease = t => 1 - Math.pow(1-t, 3);
    const overshoot = 18;

    function frame(now){
      const el = now - t0;
      if(el < DRAW_DUR){
        const p = ease(el/DRAW_DUR);
        // draw cable
        cablePath.style.strokeDashoffset = L*(1-p);
        cableHi.style.strokeDashoffset = L*(1-p);
        // plug rides the drawn tip
        const pt = sampleCable(p);
        plug.setAttribute('transform', `translate(${pt.x} ${pt.y}) rotate(${pt.angle})`);
        requestAnimationFrame(frame);
      } else if(el < DRAW_DUR + 180){
        // tiny push-in overshoot along last tangent
        const pt = sampleCable(1);
        const rad = pt.angle * Math.PI/180;
        const push = Math.sin(((el-DRAW_DUR)/180)*Math.PI) * overshoot;
        plug.setAttribute('transform', `translate(${pt.x + Math.cos(rad)*push} ${pt.y + Math.sin(rad)*push}) rotate(${pt.angle})`);
        cablePath.style.strokeDashoffset = 0;
        cableHi.style.strokeDashoffset = 0;
        requestAnimationFrame(frame);
      } else {
        const pt = sampleCable(1);
        plug.setAttribute('transform', `translate(${pt.x} ${pt.y}) rotate(${pt.angle})`);
        onConnect();
      }
    }
    requestAnimationFrame(frame);
  }

  function onConnect(){
    // laptop LED flick
    const led = dir==='ltr' ? laptopLedL : laptopLedR;
    led.style.transition='opacity .18s';
    led.style.opacity='1';
    // tiny laptop kick
    const s = SCENE[dir];
    laptop.style.transition='transform .25s cubic-bezier(.2,.9,.2,1.2)';
    laptop.setAttribute('transform', `translate(${s.laptopX} ${s.laptopY+2})`);
    setTimeout(()=>{ laptop.setAttribute('transform', `translate(${s.laptopX} ${s.laptopY})`); }, 160);

    // threads burst
    threadData.forEach((th,i)=>{
      setTimeout(()=>{
        th.pathEl.style.strokeDashoffset = 0;
        th.glowEl.style.strokeDashoffset = 0;
        th.chip.style.opacity = '1';
        th.packet.style.opacity = '.9';
      }, 35*i);
    });

    setTimeout(()=>{ document.getElementById('heroCopy').classList.add('in'); }, 500);
  }

  function setDirection(d){
    dir = d;
    if(rafId) cancelAnimationFrame(rafId);
    positionScene();
    // hide plug + leds + copy
    plug.style.opacity='0';
    wallLed.style.opacity='0';
    laptopLedR.style.opacity='0';
    laptopLedL.style.opacity='0';
    document.getElementById('heroCopy').classList.remove('in');
    buildThreads();
    threadData.forEach(th=>{
      th.pathEl.style.transition='none'; th.glowEl.style.transition='none';
      th.pathEl.style.strokeDashoffset = 1200; th.glowEl.style.strokeDashoffset = 1200;
      th.chip.style.opacity='0'; th.packet.style.opacity='0';
    });
    requestAnimationFrame(()=>{
      threadData.forEach(th=>{
        th.pathEl.style.transition='stroke-dashoffset 1.2s cubic-bezier(.2,.8,.2,1)';
        th.glowEl.style.transition='stroke-dashoffset 1.4s cubic-bezier(.2,.8,.2,1)';
      });
      playPlugIn();
      startAmbient();
    });
  }

  svg.addEventListener('pointermove', e=>{
    const r = svg.getBoundingClientRect();
    pointer.x = ((e.clientX - r.left)/r.width)*VB.w;
    pointer.y = ((e.clientY - r.top)/r.height)*VB.h;
    pointer.active = true;
  });
  svg.addEventListener('pointerleave', ()=>{ pointer.active=false; });

  return { setDirection, buildThreads };
})();

