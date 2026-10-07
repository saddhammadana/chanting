# Security Policy

Chanting is designed as an offline app: no accounts, no analytics, no ads SDK, and
no backend service for normal use.

## Reporting a Vulnerability

Report security or privacy issues privately, either through
[GitHub's private vulnerability reporting](https://github.com/saddhammadana/chanting/security/advisories/new)
or by email:

`saddhammadana@gmail.com`

Please do not open a public issue for them.

Please include:

- affected platform and app version
- steps to reproduce
- expected and actual behavior
- whether the issue can expose user-created local data, camera frames,
  notifications, or build/signing material

Do not publish exploit details before the maintainer has had time to investigate.

## Sensitive Material

Never commit:

- Android signing keystores
- `android/key.properties`
- passwords, access tokens, API keys, or CI secrets
- private store-console exports or identity-verification documents

The app should continue to work without a backend. Any change that introduces
network transfer, telemetry, crash reporting, ads, or account data must update the
privacy policy, Play data-safety notes, and README in the same change.
