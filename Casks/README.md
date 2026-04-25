# Homebrew Cask

`Casks/manfath.rb` is the formula users install with:

```sh
brew install --cask Dnymte/tap/manfath
```

## How distribution works

1. **Build & notarize**: `Scripts/release.sh` produces a signed, stapled
   `Manfath-<version>.dmg` in `build/`.
2. **Publish**: upload that DMG to a GitHub release tagged `v<version>`.
3. **Update the cask**: bump `version` and replace `sha256` with the
   output of `shasum -a 256 build/Manfath-*.dmg`.
4. **Push to the tap**: copy `Casks/manfath.rb` into the
   `Dnymte/homebrew-tap` repository (or wherever you publish your tap).
   Homebrew users will see the new version on their next `brew update`.

## One-time tap setup

Create the public tap repo once (a GitHub repo named
`homebrew-tap` under your user/org):

```sh
gh repo create Dnymte/homebrew-tap --public \
    --description "Homebrew tap for Manfath" \
    --add-readme
git clone https://github.com/Dnymte/homebrew-tap.git
cd homebrew-tap
mkdir -p Casks
cp /path/to/Manfath/Casks/manfath.rb Casks/
git add . && git commit -m "Initial cask"
git push
```

After that, every release just needs an update to the `version` and
`sha256` values inside `Casks/manfath.rb` and a push.

## Bumping the version (cheat sheet)

```sh
SHA=$(shasum -a 256 build/Manfath-0.2.0.dmg | awk '{print $1}')
sed -i '' \
    -e 's/version "0\.1\.0"/version "0.2.0"/' \
    -e "s/sha256 \"[a-f0-9]*\"/sha256 \"$SHA\"/" \
    Casks/manfath.rb
```

## Why a tap, not homebrew-cask?

Lower friction. Submitting to `homebrew-cask` would make installs even
shorter (`brew install --cask manfath`) but every release goes through
their review queue. A self-hosted tap publishes immediately and lets
the project move at its own pace. We can graduate to homebrew-cask
later once the release cadence is stable and the cask passes their
linter cleanly (`brew audit --new --cask Casks/manfath.rb`).
