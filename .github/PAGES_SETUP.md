# GitHub Pages + custom domain (`manfath.dev`)

The repo deploys `web/` to GitHub Pages via the
[`pages.yml`](workflows/pages.yml) workflow on every push to `main`.
After the first push, two one-time steps wire the custom domain:

## 1. Enable Pages with the GitHub Actions source

GitHub → repo **Settings → Pages**:

- **Source**: GitHub Actions
- The `Deploy landing page` workflow handles the rest.

The first run will publish to `https://dnymte.github.io/manfath/`.

## 2. Point `manfath.dev` at GitHub Pages

At your DNS provider (the registrar where `manfath.dev` was bought):

| Record type | Host | Value |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| AAAA | `@` | `2606:50c0:8000::153` |
| AAAA | `@` | `2606:50c0:8001::153` |
| AAAA | `@` | `2606:50c0:8002::153` |
| AAAA | `@` | `2606:50c0:8003::153` |
| CNAME | `www` | `dnymte.github.io` |

(Reference: [GitHub Pages — Apex domain DNS](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain).)

## 3. Set the custom domain in the repo

GitHub → repo **Settings → Pages → Custom domain** → enter `manfath.dev` →
**Save**.

The repo already contains `web/CNAME` with `manfath.dev`, so even if
you don't hit Save, every deploy carries the domain along.

GitHub will probe the DNS for ~10 minutes, then offer **Enforce HTTPS** —
tick it once it lights up. Cert provisioning takes a couple more minutes.

## 4. Verify

```sh
curl -I https://manfath.dev
# expect: HTTP/2 200, server: GitHub.com, content-type: text/html
```

If the deploy ever needs to run on demand (e.g. you edited workflow
config), open Actions → Deploy landing page → **Run workflow**.

## Limits (free plan)

- 1 GB site size — the landing page is ~100 KB
- 100 GB / month bandwidth — comfortably enough
- 10 builds / hour — more than enough for the rare push
- One custom domain per repo (apex + `www` count as one)

All free for public repos forever. No credit card.
