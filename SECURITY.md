# Security policy

Tamil Taxi handles phone numbers, live locations and driver identity documents, so security reports are very welcome.

## Reporting a vulnerability

**Please don't open a public issue.** Report privately through
[GitHub Security Advisories](https://github.com/sivakrishnacode/tamiltaxi/security/advisories/new) ("Report a
vulnerability").

Include:

- what is affected (API endpoint, app screen, admin page, infra config);
- steps to reproduce, or a proof of concept;
- the impact you expect (data exposed, account takeover, cost abuse…).

You'll get a reply within 7 days. Once a fix ships, you'll be credited in the advisory, unless you'd rather not be.

## Scope

- In scope: the code in this repository and its default configuration.
- **Out of scope:** the staging server (`*.sslip.io`, `65.0.233.253`). It holds test data only, and it isn't a
  target for scanning or load testing. Please run your own copy with `docker compose up -d` instead.

## Good to know

- Dev mode (`OTP_DEV_MODE=true`) skips SMS. In production it accepts only the secret `DEV_OTP_CODE`, and the API
  refuses to start without one.
- Secrets live in `.env` files, `/.dart-defines.json` and `docs/tech-docs/credentials.local.md`, which are all
  git-ignored. If you find a real key committed anywhere, report it as above.
