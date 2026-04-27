/* ══════════════════════════════════════════════════════════════
   i18n dictionary. English source on top, Arabic translation below.
   Apply via `applyLang('en' | 'ar')`; the `<html dir>` flips
   automatically for RTL.
══════════════════════════════════════════════════════════════ */
const I18N = {
  en:{
    "brand":"Manfath",
    "nav.features":"Features","nav.oss":"Open source","nav.blog":"Blog","nav.download":"Download",
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
    "faq.eyebrow":"Common questions",
    "faq.title":"Things developers ask before they install.",
    "faq.q1":"What is Manfath, exactly?",
    "faq.a1":"Manfath is a free, open-source macOS menu bar app. It lists every listening localhost port on your machine, shows the process and PID behind each one, lets you kill any process with one click, and exposes any local port to the public internet via Cloudflare or ngrok. It runs entirely on your machine — no accounts, no telemetry.",
    "faq.q2":"How do I find a port on Mac Terminal?",
    "faq.a2":"Open Terminal (Cmd+Space → \"Terminal\") and run <code>lsof -nP -iTCP:3000 -sTCP:LISTEN</code> — replace 3000 with the port you want. The PID column tells you which process owns the port. <code>lsof</code> is preinstalled on every macOS version. With Manfath, the same answer is in your menu bar — every port, refreshed every 3 seconds, sorted by activity.",
    "faq.q3":"How do I kill a process on a port?",
    "faq.a3":"CLI: <code>kill -9 $(lsof -ti :3000)</code>. Manfath does the same with one click — SIGTERM first (so the process can clean up), escalating to SIGKILL only if it refuses to exit.",
    "faq.q4":"Is it really free?",
    "faq.a4":"Yes. MIT-licensed, no paid tier, no upsell, no telemetry. The full source is on GitHub.",
    "faq.q5":"What's a free alternative to ngrok?",
    "faq.a5":"Cloudflare Tunnel (<code>cloudflared</code>) is free and unlimited. Manfath ships with Cloudflare and ngrok built-in — pick a port, click Tunnel, the public URL lands in your clipboard.",
    "faq.q6":"Does it work with Docker, Vite, Next.js, Rails…?",
    "faq.a6":"Yes — Manfath sees processes, not frameworks. Anything that opens a listening socket on macOS shows up: Vite, Next.js, Rails, Django, Express, FastAPI, Postgres, Redis, Docker-mapped host ports, and so on.",
    "faq.q7":"Why not just use lsof?",
    "faq.a7":"Use it when you already know the port and you're already in a terminal. Manfath is the always-visible, sortable, filterable, killable, tunnel-able view of <em>everything</em> that's listening — for the case where you don't yet know what's running.",
    "faq.more":"Longer reads on",
    "faq.more.link":"the Manfath blog",
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
    "nav.features":"الميزات","nav.oss":"مفتوح المصدر","nav.blog":"المدونة","nav.download":"تحميل",
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
    "faq.eyebrow":"الأسئلة الشائعة",
    "faq.title":"ما يسأله المطوّرون قبل التثبيت.",
    "faq.q1":"ما هو Manfath بالضبط؟",
    "faq.a1":"تطبيق مجاني ومفتوح المصدر لشريط القوائم في macOS. يُظهر كل منفذ localhost مستمع على جهازك مع اسم العملية والـPID خلف كلٍّ منها، يتيح إنهاء أي عملية بنقرة، ويكشف أي منفذ محلي إلى الإنترنت العام عبر Cloudflare أو ngrok. يعمل بالكامل على جهازك — بلا حسابات، بلا تتبّع.",
    "faq.q2":"كيف أجد المنفذ في الطرفية (الترمنال) على ماك؟",
    "faq.a2":"افتح الطرفية (Cmd+Space ثم اكتب «Terminal») وشغّل <code>lsof -nP -iTCP:3000 -sTCP:LISTEN</code> — استبدل 3000 بالمنفذ المطلوب. عمود الـPID يخبرك بالعملية المالكة للمنفذ. أداة <code>lsof</code> مثبّتة مسبقاً في كل إصدارات macOS. مع Manfath، تجد الإجابة نفسها في شريط القوائم — كل المنافذ، تُحدَّث كل 3 ثوانٍ، مرتّبة بالنشاط.",
    "faq.q3":"كيف أنهي عملية تستخدم منفذاً ما؟",
    "faq.a3":"عبر الطرفية: <code>kill -9 $(lsof -ti :3000)</code>. Manfath يفعل نفس الشيء بنقرة واحدة — SIGTERM أولاً (لتفسح للعملية مجال التنظيف)، ثم SIGKILL فقط إن رفضت الإنهاء.",
    "faq.q4":"هل هو فعلاً مجاني؟",
    "faq.a4":"نعم. ترخيص MIT، بلا خطة مدفوعة، بلا ترقيات، بلا تتبّع. الكود الكامل على GitHub.",
    "faq.q5":"ما البديل المجاني لـ ngrok؟",
    "faq.a5":"Cloudflare Tunnel (<code>cloudflared</code>) مجاني وبلا حدود. Manfath يأتي بـ Cloudflare و ngrok مدمجَين — اختر منفذاً، انقر «نفق»، يُنسخ الرابط العام إلى حافظتك مباشرة.",
    "faq.q6":"هل يعمل مع Docker و Vite و Next.js و Rails…؟",
    "faq.a6":"نعم — Manfath يرى العمليات لا الأُطر. أي شيء يفتح مقبس استماع على macOS يظهر: Vite و Next.js و Rails و Django و Express و FastAPI و Postgres و Redis ومنافذ Docker المضيفة وغيرها.",
    "faq.q7":"لمَ لا أكتفي بـ lsof؟",
    "faq.a7":"استخدمه عندما تعرف المنفذ مسبقاً وأنت أصلاً في الطرفية. Manfath هو العرض الدائم القابل للترتيب والتصفية والإنهاء والتنفيق لِـ<em>كل</em> ما يستمع — للحالة التي لا تعرف فيها بعد ما يعمل.",
    "faq.more":"قراءات أطول على",
    "faq.more.link":"مدوّنة Manfath",
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
    // Use innerHTML so we can ship inline <code>/<em> snippets in
    // strings (e.g. FAQ answers). All strings come from this dictionary
    // — never user input — so there's no XSS surface.
    if(I18N[lang][key] !== undefined) el.innerHTML = I18N[lang][key];
  });
  // Point the Blog nav link to the right language mirror.
  document.querySelectorAll('a[data-blog-link]').forEach(a => {
    a.setAttribute('href', isAR ? '/blog/ar/' : '/blog/');
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
