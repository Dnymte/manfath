/* ══════════════════════════════════════════════════════════════
   i18n dictionary. English source on top, Arabic translation below.
   Apply via `applyLang('en' | 'ar')`; the `<html dir>` flips
   automatically for RTL.
══════════════════════════════════════════════════════════════ */
const I18N = {
  en:{
    "brand":"Manfath",
    "nav.features":"Features","nav.oss":"Open source","nav.download":"Download",
    "hero.eyebrow":"v1.0 · Free forever",
    "hero.title.line1":"See every port.",
    "hero.title.line2":"Kill what you don't need.",
    "hero.title.line3":"Share the rest.",
    "hero.sub":"A free, open-source menu bar app for macOS that shows every localhost port on your machine — with one-click kill and public tunnels built in.",
    "hero.cta.download":"Download for Mac",
    "hero.cta.github":"View on GitHub",
    "hero.foss":"Free and open source. Forever.",
    "dash.eyebrow":"The menu bar, live",
    "dash.title":"Every port. Always visible.",
    "dash.sub":"One keyboard shortcut opens the scanner. Sorted by activity, filterable by name, and always current — Manfath re-scans every three seconds.",
    "pop.title":"Listening on localhost",
    "pop.meta":"8 ports · last scan 0.8s ago",
    "pop.search":"Search ports, processes, PIDs…",
    "pop.foot.left":"Scanning every 3s",
    "pop.foot.right":"⌘, preferences  ·  ⌘Q quit",
    "feat.eyebrow":"Three things, done well",
    "feat.title":"Scan. Kill. Tunnel.",
    "feat.1.title":"Scan",
    "feat.1.body":"Every listening port, every 3 seconds, zero config. TCP, UDP, IPv4, IPv6 — with the process name and PID behind each one.",
    "feat.2.title":"Kill",
    "feat.2.body":"Stuck process on :3000? One click, it's gone. SIGTERM first, SIGKILL if it misbehaves — with zero terminal yoga.",
    "feat.3.title":"Tunnel",
    "feat.3.body":"Share localhost with a public URL in one line. Cloudflare, ngrok, or your own — Manfath wires it up and copies the link.",
    "stack.eyebrow":"Works with your stack",
    "stack.title":"Wired to whatever you're building.",
    "stack.sub":"Manfath sees processes, not frameworks — which means it sees everything. Here's a weekend's worth of side projects, all in one glance.",
    "tun.eyebrow":"One line. One link.",
    "tun.title":"Push any port past your firewall.",
    "tun.sub":"A thread leaves your machine, reaches a public URL, and comes back as a link in your clipboard. No config, no dashboard login.",
    "tun.toast":"Copied",
    "oss.eyebrow":"Open source, without asterisks",
    "oss.title":"Free forever. MIT. No accounts, no telemetry, no upsell.",
    "oss.body":"Manfath is built in the open. Star us on GitHub, file an issue, or send a PR. The whole app is a few thousand lines of Swift — a good place to learn how menu bar apps work.",
    "oss.stars":"stars","oss.license":"license","oss.contrib":"contributors","oss.version":"version",
    "privacy.1":"Everything runs on your machine.",
    "privacy.2":"Nothing leaves it",
    "privacy.3":"unless",
    "privacy.4":"you",
    "privacy.5":"tunnel it.",
    "dl.eyebrow":"Ready in 30 seconds",
    "dl.title":"Download Manfath",
    "dl.sub":"Universal binary — Apple Silicon and Intel. macOS 14 Sonoma or later.",
    "dl.primary":"Download Manfath 1.0.0",
    "dl.releases":"All releases",
    "dl.copy":"COPY",
    "dl.fine1":"Prefer the raw .dmg?",
    "dl.fine2":"Grab it from GitHub releases",
    "foot.made":"Made with care.",
    "meta.title":"Manfath — See every port. Kill what you don't need. Share the rest.",
    "meta.description":"Free, open-source macOS menu bar app that shows every localhost port — scan, kill, and tunnel in one click. No accounts, no telemetry."
  },
  ar:{
    "brand":"منفذ",
    "nav.features":"الميزات","nav.oss":"مفتوح المصدر","nav.download":"تحميل",
    "hero.eyebrow":"الإصدار 1.0 · مجاني للأبد",
    "hero.title.line1":"شاهد كل منفذ.",
    "hero.title.line2":"أوقف ما لا تحتاجه.",
    "hero.title.line3":"شارك الباقي.",
    "hero.sub":"تطبيق مجاني ومفتوح المصدر لشريط القوائم في macOS يُظهر كل منفذ localhost على جهازك — مع إنهاء العمليات بنقرة واحدة وأنفاق عامة مدمجة.",
    "hero.cta.download":"تحميل لـ Mac",
    "hero.cta.github":"عرض على GitHub",
    "hero.foss":"مجاني ومفتوح المصدر. إلى الأبد.",
    "dash.eyebrow":"شريط القوائم، حيّ",
    "dash.title":"كل منفذ. مرئي دائماً.",
    "dash.sub":"اختصار واحد يفتح الماسح. مرتّب حسب النشاط، قابل للتصفية بالاسم، ومحدّث دائماً — يُعيد Manfath المسح كل ثلاث ثوانٍ.",
    "pop.title":"الاستماع على localhost",
    "pop.meta":"8 منافذ · آخر مسح قبل 0.8 ثانية",
    "pop.search":"ابحث عن منافذ أو عمليات أو PIDs…",
    "pop.foot.left":"مسح كل 3 ثوانٍ",
    "pop.foot.right":"⌘, التفضيلات · ⌘Q إنهاء",
    "feat.eyebrow":"ثلاثة أشياء، تُنجَز بإتقان",
    "feat.title":"مسح. إنهاء. نفق.",
    "feat.1.title":"مسح",
    "feat.1.body":"كل منفذ مستمع، كل 3 ثوانٍ، بلا أي إعدادات. TCP و UDP و IPv4 و IPv6 — مع اسم العملية و PID لكل واحد.",
    "feat.2.title":"إنهاء",
    "feat.2.body":"عملية عالقة على :3000؟ نقرة واحدة وانتهت. SIGTERM أولاً، ثم SIGKILL إن لزم — بلا أي رياضات طرفية.",
    "feat.3.title":"نفق",
    "feat.3.body":"شارك localhost برابط عام في سطر واحد. Cloudflare أو ngrok أو نفقك الخاص — يهيّئه Manfath وينسخ الرابط لك.",
    "stack.eyebrow":"يعمل مع منصّتك",
    "stack.title":"متصل بأي شيء تبنيه.",
    "stack.sub":"يرى Manfath العمليات لا الأُطر — مما يعني أنه يرى كل شيء. هذه مشاريع جانبية بقدر عطلة أسبوع، كلها في لمحة.",
    "tun.eyebrow":"سطر واحد. رابط واحد.",
    "tun.title":"شارك أي منفذ خارج جدار الحماية.",
    "tun.sub":"يغادر جهازك، يصل إلى رابط عام، ويعود إليك كرابط في الحافظة. بلا إعدادات، بلا تسجيل دخول للوحة تحكم.",
    "tun.toast":"تم النسخ",
    "oss.eyebrow":"مفتوح المصدر، بلا شروط جانبية",
    "oss.title":"مجاني للأبد. ترخيص MIT. لا حسابات، لا تتبّع، لا ترقيات مدفوعة.",
    "oss.body":"Manfath مبني في العلن. ضع نجمة على GitHub، افتح مشكلة، أو أرسل PR. التطبيق بأكمله بضعة آلاف من أسطر Swift — مكان جيّد لتعلّم كيف تعمل تطبيقات شريط القوائم.",
    "oss.stars":"نجوم","oss.license":"ترخيص","oss.contrib":"المساهمون","oss.version":"الإصدار",
    "privacy.1":"كل شيء يعمل على جهازك.",
    "privacy.2":"لا شيء يغادره",
    "privacy.3":"إلا",
    "privacy.4":"إذا",
    "privacy.5":"شاركته.",
    "dl.eyebrow":"جاهز خلال 30 ثانية",
    "dl.title":"تحميل Manfath",
    "dl.sub":"ثنائي عالمي — Apple Silicon و Intel. macOS 14 Sonoma أو أحدث.",
    "dl.primary":"تحميل Manfath 1.0.0",
    "dl.releases":"كل الإصدارات",
    "dl.copy":"نسخ",
    "dl.fine1":"تفضّل ملف .dmg مباشرة؟",
    "dl.fine2":"احصل عليه من إصدارات GitHub",
    "foot.made":"صُنع بعناية.",
    "meta.title":"منفذ — شاهد كل منفذ. أوقف ما لا تحتاجه. شارك الباقي.",
    "meta.description":"تطبيق مجاني ومفتوح المصدر لشريط القوائم في macOS يعرض كل منفذ localhost — مسح وإنهاء وأنفاق بنقرة واحدة. بلا حسابات، بلا تتبّع."
  }
};

/* ───────── language toggle ───────── */
function applyLang(lang){
  const html = document.documentElement;
  const isAR = lang === 'ar';
  html.lang = isAR ? 'ar' : 'en';
  html.dir  = isAR ? 'rtl' : 'ltr';
  document.querySelectorAll('[data-i18n]').forEach(el=>{
    const key = el.getAttribute('data-i18n');
    if(I18N[lang][key] !== undefined) el.textContent = I18N[lang][key];
  });
  // Swap localized SEO so crawlers and shares see the right strings.
  const title = I18N[lang]['meta.title'];
  const desc  = I18N[lang]['meta.description'];
  if(title) document.title = title;
  const metaDesc = document.getElementById('metaDesc');
  if(metaDesc && desc) metaDesc.setAttribute('content', desc);
  document.getElementById('lang-en').classList.toggle('on', !isAR);
  document.getElementById('lang-en').setAttribute('aria-pressed', String(!isAR));
  document.getElementById('lang-ar').classList.toggle('on', isAR);
  document.getElementById('lang-ar').setAttribute('aria-pressed', String(isAR));
  try{ localStorage.setItem('manfath.lang', lang); }catch(e){}
  // re-run hero animation direction + redraw threads
  heroController.setDirection(isAR ? 'rtl' : 'ltr');
  drawStackThreads();
  drawTunnelDemo();
}
document.getElementById('lang-en').addEventListener('click', ()=>applyLang('en'));
document.getElementById('lang-ar').addEventListener('click', ()=>applyLang('ar'));
