# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project Posture

SIPMan is a macOS SIP softphone with an Xcode project, Swift,
Objective-C, C, and vendored third-party C libraries built locally into
`ThirdParty/`.

Prefer small, conservative changes that match the existing code style.
Read nearby code before introducing new patterns.

## Build And Test

Use the dependency bootstrap script when the ignored third-party
artifacts are missing:

```sh
scripts/bootstrap-third-party.sh
```

Use this command for a local Debug app build:

```sh
xcodebuild -project SIPMan.xcodeproj -scheme SIPMan -configuration Debug -derivedDataPath /tmp/sipman-deriveddata CODE_SIGNING_ALLOWED=NO build
```

Where possible, build or test the smallest relevant scheme first, then
run the full `SIPMan` scheme before considering a change complete.

## Tests For New Code

Where possible, always create a small test framework around new code.
Prefer focused tests near the existing target that owns the behavior:

- `DomainTests` for domain logic.
- `UseCasesTests` for use-case behavior.
- `ReceiptValidationTests` for receipt-validation changes.
- `TelephoneTests` for application-level behavior that already belongs
  in the app target.

If a change cannot be reasonably tested with the current project
structure, explain why in the final notes and leave a clear manual test
path.

## Comments

Keep comments useful and intentional. Do not narrate obvious code.

If the area is complex, subtle, legacy-heavy, or proving troublesome,
comment code thoroughly enough that the next maintainer can understand
the intention behind the approach, the constraints that shaped it, and
any tradeoffs that remain.

## Versioning

When changes have been approved or tested, commit them to the Git
repository.

Bump relevant version numbers as part of the same completed change:

- For app/runtime changes, increment `CURRENT_PROJECT_VERSION`.
- For release-level user-facing changes, update `MARKETING_VERSION`.
- For documentation-only or local tooling changes, do not bump app
  binary versions unless explicitly requested.

Keep version changes scoped and mention them in `CHANGELOG.md`.

## Changelog

Maintain `CHANGELOG.md` in the project root.

Add a concise entry for every completed change that affects users,
developers, build setup, tests, or project maintenance. Use the existing
topmost version section unless the change starts a new release.

## Git Hygiene

Do not commit ignored third-party build products under `ThirdParty/`.
Only commit source, project files, scripts, tests, documentation, and
tracked configuration such as `ThirdParty/PJSIP/config_site.h`.

Do not revert unrelated user changes. If unrelated changes are present,
leave them alone and commit only the files involved in the current task.
