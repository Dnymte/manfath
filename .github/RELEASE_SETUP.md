# Release workflow setup

`.github/workflows/release.yml` runs on every `v*` tag push. It builds,
signs, notarizes, packages a DMG, creates the GitHub release, and
optionally bumps the Homebrew tap. None of that works until the secrets
below are populated in **Settings → Secrets and variables → Actions**.

## Required secrets

| Name | What it is | How to get it |
|------|------------|---------------|
| `APPLE_ID` | The Apple ID email for the developer account | e.g. `you@example.com` |
| `APPLE_TEAM_ID` | 10-char team identifier | Apple Developer → Membership |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool` | [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords |
| `CODE_SIGN_IDENTITY` | Full identity name | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `DEVELOPER_ID_CERT_P12` | base64-encoded `.p12` of your Developer ID Application cert | see "Exporting the cert" below |
| `DEVELOPER_ID_CERT_PASSWORD` | The password you set when exporting the `.p12` | choose any value, just keep it consistent |
| `KEYCHAIN_PASSWORD` | Throwaway password for the temporary keychain | generate with `openssl rand -base64 24` |

## Optional secrets

| Name | What it is |
|------|------------|
| `TAP_PUSH_TOKEN` | Personal access token with `contents: write` on `Dnymte/homebrew-tap`. If set, the release workflow auto-bumps the cask formula and pushes. If unset, the bump step is skipped — do it manually. |

## Exporting the cert

1. Open **Keychain Access**
2. Find your `Developer ID Application: …` certificate under
   *login → My Certificates*. The disclosure triangle should reveal
   the matching private key — **both must be selected**.
3. Right-click → **Export 2 items…** → Save as `developer-id.p12`.
   Set a password (this becomes `DEVELOPER_ID_CERT_PASSWORD`).
4. Encode for the secret:
   ```sh
   base64 -i developer-id.p12 | pbcopy
   ```
   Paste into `DEVELOPER_ID_CERT_P12`.

## Cutting a release

```sh
git tag v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

The workflow runs in ~6–8 minutes (most of it is the notary wait).
When it finishes, `https://github.com/Dnymte/manfath/releases/tag/v1.0.0`
contains the signed DMG.

If `TAP_PUSH_TOKEN` is configured, `Dnymte/homebrew-tap` gets bumped
automatically. Otherwise update `Casks/manfath.rb` in the tap by hand
following [`Casks/README.md`](../Casks/README.md).

## Local-only release

`Scripts/release.sh` is the same script the workflow runs, with the
same env vars. To smoke-test the pipeline locally before tagging:

```sh
DEVELOPMENT_TEAM="YOURTEAMID" \
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (YOURTEAMID)" \
NOTARY_PROFILE="manfath-notary" \
./Scripts/release.sh
```

`SKIP_NOTARIZE=1` shortcuts the notary submission.
