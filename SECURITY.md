# Security policy

## Reporting a vulnerability

Manfath runs `lsof` and sends `SIGTERM` / `SIGKILL` to processes you
own. If you find a way to escalate privileges, escape the hardened
runtime, or coerce the app into killing or exposing a process the
running user shouldn't be able to touch — please report it
**privately** rather than opening a public issue.

Open a GitHub
[Security Advisory](https://github.com/Dnymte/manfath/security/advisories/new).

I'll acknowledge within 72 hours, fix as quickly as feasible, and
credit you in the release notes (unless you prefer not).

## Supported versions

Only the latest released version receives security fixes. Cut releases
land via Homebrew (`brew upgrade --cask manfath`).

## Out of scope

- Bugs in third-party tools Manfath calls out to (`lsof`, `kill`,
  `cloudflared`, `ngrok`). Report those upstream.
- Issues that require an attacker to already have local code execution
  as your user account — `lsof` and `kill` are the same primitives
  any local process can use.
