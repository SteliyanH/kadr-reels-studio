# fastlane

Release-engineering setup for Reels Studio. v0.6 Tier 8 baseline.

## One-time setup

1. **Install** the tooling.
   ```sh
   brew install xcodegen
   bundle install
   ```

2. **Create the private signing repo** that `match` reads certificates from. Suggested name: `<owner>/ios-certificates`. Must be private.

3. **Set environment variables** (locally in `~/.zshrc` or your secrets manager; in CI as repository secrets):
   ```sh
   export APP_IDENTIFIER=com.steliyanh.reels-studio
   export APPLE_ID=dev@example.com
   export TEAM_ID=ABCDE12345              # 10-char Apple Developer Team ID
   export ITC_TEAM_ID=                    # optional, numeric App Store Connect team
   export MATCH_GIT_URL=https://github.com/<owner>/ios-certificates.git
   export MATCH_PASSWORD=<long-random>    # encrypts the cert repo
   export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=  # if 2FA on the Apple ID
   ```

4. **Initialize match** (once) — generates the App Store distribution cert + provisioning profile and pushes them to the cert repo encrypted with `MATCH_PASSWORD`:
   ```sh
   bundle exec fastlane refresh_match
   ```

## Lanes

| Lane | What it does |
|---|---|
| `beta` | Build Release, upload to TestFlight. Used by the `Release` workflow. |
| `release` | Build Release, upload to App Store (manual submission gate — `submit_for_review: false` until v1.0). |
| `refresh_match` | Re-sync signing certs from the match repo. Run after rotating or on a fresh machine. |

Each invocation regenerates `ReelsStudio.xcodeproj` via xcodegen first so a stale checkout doesn't drift from `project.yml`.

## CI integration (deferred)

A dedicated GitHub Actions workflow that runs `bundle exec fastlane beta` on tag push will land in a follow-up alongside the first TestFlight build. Holding it back from v0.6 because it needs the secrets above wired into repo settings and a verified TestFlight account.
