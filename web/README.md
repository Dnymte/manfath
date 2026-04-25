# Manfath landing page

Static html / css / js — no build step. Designed for `manfath.dev`.

## Run locally

Any static server works:

```sh
cd web
python3 -m http.server 8000
# → open http://localhost:8000
```

## Deploy

Drop `index.html` on any static host:

- **GitHub Pages**: enable Pages on the `Dnymte/manfath` repo, set
  source to `main /web`. Set the custom domain to `manfath.dev`.
- **Cloudflare Pages**: connect the repo, build command empty, output
  directory `web`.
- **Netlify / Vercel**: same — root `web`, no build.

## What's wired

- **Live stars / contributors / version** — fetched from the GitHub
  API on page load (`fetchRepoStats()` near the bottom of the file).
  Falls back to dashes on error / rate limit.
- **Brew install command** — points at the Homebrew tap path,
  `brew install --cask Dnymte/tap/manfath`.
- **Language switcher** — English / Arabic, persisted in
  `localStorage` under `manfath.lang`. RTL flip is automatic.

## Updating

The values most likely to need touching:

| What | Where |
|------|-------|
| Repo slug | `const REPO = 'Dnymte/manfath'` near the bottom of `<script>` |
| Brew command | search for `brew install --cask` (two places: visible block + clipboard handler) |
| Default version label | `id="ghVersion"` initial text (overridden live by API) |
| Hero version eyebrow | `"hero.eyebrow"` in `I18N.en` / `I18N.ar` |
| Translations | `I18N.ar` block — keys mirror the `en` block 1:1 |
