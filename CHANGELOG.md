# Changelog

## 1.7
- Added the initial SwiftUI softphone shell inside the existing account
  window.
- Added a UI-ready recent-call history item model and adapter for inbound,
  outbound, and missed calls.
- Added an in-call stats model, quality evaluator, stats store, and
  PJSIP-backed `AKSIPCall` stats sampler.
- Added PJSIP in-call stats documentation for the desktop app effort.
- Added stable SIP MESSAGE conversation IDs generated from normalized
  sender and recipient participants.
- Added a SIP MESSAGE data model for future messaging UI work.
- Removed the Telephone Pro subscription prompt and unlocked the full
  call history and 30 simultaneous-call limit without a purchase check.
- Added a shared app test scheme and local test runner script.
- Minimum deployment target 13.5.
- Added repeatable third-party dependency bootstrap instructions and
  script.
- Added repository agent guidance for builds, tests, versioning,
  comments, changelog maintenance, and Git hygiene.

## 1.6 - 2022-06-29
- macOS Big Sur.
- Apple silicon.
- Minimum deployment target 10.13.
- Fixed an issue where matching contact for an incoming call could not
  be found when the incoming phone number was exactly the same length
  as the significant phone number setting and the contact's phone
  number was longer than that.
- Remove user notification when incoming call is answered or declined.
- Allow the app settings to be copied to clipboard as text.
- LibreSSL 3.1.5.
