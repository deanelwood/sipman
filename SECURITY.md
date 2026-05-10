# Security Policy

## Supported Versions

SIPMan is currently pre-release software. Security fixes are made on the
default branch unless release branches are introduced later.

## Reporting a Vulnerability

Please do not open a public issue or pull request containing vulnerability
details, exploit steps, credentials, packet captures, or sensitive SIP traces.

Preferred reporting path:

1. Use GitHub private vulnerability reporting for this repository if it is
   enabled.
2. If private vulnerability reporting is unavailable, contact the maintainer
   privately through their GitHub profile contact details or another private
   channel you already have.
3. If no private route is available, open a public issue asking for a security
   contact, but do not include technical details.

Please include:

- A concise description of the vulnerability.
- Affected SIPMan commit, build, or release.
- Steps to reproduce in a safe test environment.
- Expected impact and any known mitigations.
- Whether any sensitive data, credentials, or real systems were involved.

## Response Process

The maintainer will aim to:

- Acknowledge reports as soon as practical.
- Triage severity based on exploitability, user impact, and exposure.
- Prepare fixes privately when public disclosure would increase risk.
- Credit reporters when requested and appropriate.
- Publish notes in `CHANGELOG.md` or a security advisory once a fix is available.

## Threat Model

SIPMan is a desktop SIP client. Security-sensitive areas include:

- SIP account credentials stored in macOS Keychain.
- SIP signaling over UDP, TCP, or TLS.
- RTP media and live call diagnostics from PJSIP.
- Local call history, SIP MESSAGE records, and SIP logs.
- Contact access requested through macOS permissions.
- Third-party native libraries, especially PJSIP, LibreSSL, Opus, and bundled
  codec libraries.

Out of scope for this repository:

- Vulnerabilities in third-party SIP servers, PBXs, SBCs, or carriers.
- Attacks that require a compromised macOS user account or malicious local
  administrator access.
- Public test systems intentionally configured with weak SIP credentials.

## Handling Sensitive Logs

SIP logs and packet captures can contain credentials, phone numbers, IP
addresses, domains, contact details, and customer data. Redact them before
sharing publicly. If full traces are needed for a security report, share them
only through a private channel.

## Maintainer Security Checklist

- Keep privileged GitHub accounts protected with multi-factor authentication.
- Use protected branches before accepting outside contributions at scale.
- Keep dependency versions and third-party notices under review.
- Enable GitHub private vulnerability reporting for the repository.
- Consider CodeQL or another static analysis workflow once CI is available.
