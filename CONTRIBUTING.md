# Contributing to SIPMan

Thanks for taking an interest in SIPMan. This project is a native macOS SIP
softphone aimed at field engineers, support teams, and SIP platform developers.
Contributions should keep that focus: a compact, reliable diagnostic tool rather
than a broad consumer communications app.

## Ways to Help

- Report reproducible SIP registration, calling, messaging, or diagnostics
  issues.
- Improve build, test, and dependency documentation.
- Add focused tests around new data models, SIP behavior, and UI-facing logic.
- Improve the macOS UI where it makes field troubleshooting clearer or faster.
- Review third-party dependency and licensing details before distribution.

## Before You Start

Open an issue before large changes, dependency upgrades, architecture changes,
or UI redesigns. Small fixes, documentation improvements, and focused tests can
go straight to a pull request.

Please avoid unrelated refactors in feature branches. SIPMan still contains
legacy Objective-C alongside newer Swift and SwiftUI code, so small, traceable
changes are easier to review safely.

## Local Setup

Build third-party dependencies:

    $ scripts/bootstrap-third-party.sh

Build the app:

    $ scripts/build-app.sh

Build and launch:

    $ scripts/build-app.sh --open

Unsigned compile-only builds are available, but signed Debug builds are better
for smoke testing because macOS Keychain access depends on the app identity:

    $ scripts/build-app.sh --unsigned

## Tests

Run the default local XCTest suite:

    $ scripts/test.sh

Run a specific scheme:

    $ scripts/test.sh --scheme TelephoneTests

Where possible, add a small test around new model, parser, state-management, or
bridge code. UI-only polish does not always need a test, but changes that affect
call state, diagnostics, messages, history, settings, or PJSIP integration
usually should.

## Pull Requests

Before opening a pull request:

- Keep `CHANGELOG.md` updated for user-visible or maintainer-visible changes.
- Bump `CURRENT_PROJECT_VERSION` for app/runtime behavior changes.
- Do not bump the build number for documentation-only changes.
- Run the relevant tests and include the result in the PR.
- Note any manual SIP smoke testing, including server, transport, and call flow.
- Keep commits focused and explain any risky or incomplete areas.

## Coding Notes

- Prefer existing repo patterns over introducing new frameworks.
- Keep SwiftUI views composed from small subviews when a screen grows.
- Preserve legacy copyright notices in files inherited from the original
  Telephone project.
- Comment complex SIP/PJSIP work with the intention behind the approach, not
  only what the code does.
- Never commit SIP credentials, packet captures with real customer data, private
  keys, provisioning profiles, or production server details.

## Reporting Bugs

Use the bug report template when possible. Include:

- macOS and Xcode versions.
- SIP server or platform type, anonymized if needed.
- Account transport, NAT, STUN/TURN, and codec settings.
- Steps to reproduce.
- Expected and actual behavior.
- Relevant SIP log excerpts with credentials, tokens, IPs, and phone numbers
  redacted where appropriate.

Do not include sensitive logs in public issues. See `SECURITY.md` for private
security reporting.
