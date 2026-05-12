# Changelog

## 1.7
- Removed the Messages conversation type filter so the sidebar keeps only
  search and new-message controls, and bumped the build number to 193.
- Made account Transport and Port editable in Settings, saving the selected SIP
  transport and registrar/proxy port with the account, and bumped the build
  number to 192.
- Grouped the History call list with human date labels such as Today,
  Yesterday, and Last week, and bumped the build number to 191.
- Added Settings controls for editing SIP account details and logging out of
  the active account, and bumped the build number to 190.
- Simplified Messages and History page headers by removing duplicate titles,
  centering filters, tightening empty states, and bumped the build number to 189.
- Changed the primary navigation sidebar to an icon-only rail so the main app
  content has more room, and bumped the build number to 188.
- Added a Settings version label backed by the app bundle version, clarified
  version-bump guidance for future changes, and bumped the build number to 187.
- Refined the Messages screen into a chat-style layout with conversation search
  and filters, cleaner message cards, a stronger conversation header, and
  bumped the build number to 186.
- Moved CodeQL analysis to GitHub's macOS 26 arm64 runner so Swift analysis
  uses a current Xcode/macOS SDK toolchain.
- Made the SIP OPTIONS Tools pane scroll within the Settings area and reduced
  the raw response panel height so ping results fit smaller windows, and bumped
  the build number to 185.
- Added a PJSIP endpoint observer for inbound and outbound SIP packets so the
  Live SIP Log pane receives real stack traffic, and bumped the build number
  to 184.
- Moved CodeQL Swift dependency bootstrap before CodeQL initialization so the
  scanner traces the app build rather than the third-party C dependency build.
- Made the third-party bootstrap script pass explicit configure host triples for
  single-architecture dependency builds so CI/CodeQL runner architecture
  detection stays aligned with the requested build architecture.
- Cached the Calling Contacts model after the first sync, moved contact loading
  off the immediate UI path, added first-run syncing feedback, and bumped the
  build number to 183.
- Applied the dark mode toggle to SIPMan's AppKit window appearance so the
  adaptive SwiftUI palette updates immediately, and bumped the build number
  to 182.
- Fixed the Calling Contacts crash by fetching every CNContact property used by
  the shared contact mapper, and bumped the build number to 181.
- Added an explicit CodeQL workflow that keeps C/C++ analysis on no-build mode
  and runs Swift analysis through SIPMan's third-party bootstrap plus unsigned
  app build.
- Made Calling's Keypad/Contacts switch more obvious, added contact-load
  diagnostics for empty local contact results, and bumped the build number
  to 180.
- Added open-source project housekeeping docs for contributing, conduct,
  security reporting, issue templates, and pull request review expectations.
- Added Account settings for username/password visibility plus editable ICE,
  STUN, and TURN server configuration backed by PJSIP network settings, and
  bumped the build number to 179.
- Added a persistent Settings dark mode toggle, introduced an adaptive SIPMan
  dark palette for the SwiftUI shell, and bumped the build number to 178.
- Added an in-call Hold/Release control backed by the existing PJSIP re-INVITE
  hold flow, and bumped the build number to 177.
- Renamed the Keypad navigation item to Calling, added Keypad and Contacts
  modes for idle calling, kept the in-call DTMF keypad direct, refreshed
  Contacts permission copy, and bumped the build number to 176.
- Raised PJSIP logging used by the live SIP Log tab to level 5 so SIP packet
  lines are captured for new and existing installs, and bumped the build number
  to 175.
- Allowed the SIP Ping tool to send OPTIONS probes without requiring the
  selected account to be registered, and bumped the build number to 174.
- Made the Settings Diagnostics pane vertically scrollable so long live-call
  media stats remain accessible in the app window, and bumped the build number
  to 173.
- Added a Settings Tools tab with a SIP Ping tool that sends PJSIP-backed
  SIP OPTIONS probes over UDP, TCP, or TLS, captures responses/timeouts, and
  bumped the build number to 172.
- Reworked the README around SIPMan's field-engineering audience, core SIP
  softphone workflows, diagnostics focus, repository layout, and build/test
  guidance.
- Added third-party dependency notices for the linked PJSIP, LibreSSL, Opus,
  and bundled codec libraries, documented distribution license files, and
  bumped the build number to 171.
- Added a Settings SIP Log tab with live rolling PJSIP stack output, kept the
  app log file in sync with the live feed, and bumped the build number to 170.
- Stopped live call timer/stat refreshes from forcing navigation back to the
  Keypad while viewing Settings diagnostics, and bumped the build number to
  169.
- Added live in-call diagnostics to Settings, including current and peak
  PJSIP media stats such as jitter, packet counts, RTT, RTP, and ICE details,
  and bumped the build number to 168.
- Prevented ended inline calls from being republished by stale status timers
  after hang-up, and bumped the build number to 167.
- Removed former-author website, FAQ, terms, privacy, subscription
  management, Credits blurb, and new-file template header references from
  first-party app surfaces, and bumped the build number to 166.
- Added a libPhoneNumber-iOS-backed display path for regular phone numbers,
  applied pretty formatting across call, history, and message presentation,
  and bumped the build number to 165.
- Updated account window titles to show `SIPman - username` without the
  SIP domain, and bumped the build number to 164.
- Removed the legacy availability toolbar from account windows, and bumped
  the build number to 163.
- Split Settings into Account and Diagnostics tabs so each pane can use the
  full content width, and bumped the build number to 162.
- Wired the History All, Inbound, and Outbound filters to the call-history
  row source, and bumped the build number to 161.
- Tightened the SwiftUI sidebar width and navigation spacing to give the
  main softphone content more room, and bumped the build number to 160.
- Moved the Messages search field into the top status row beside the
  registration pills, and bumped the build number to 159.
- Tightened the active-call keypad layout so mute and hang-up controls fit
  in the main window, removed the duplicate number display, and bumped the
  build number to 158.
- Added a signed-app build helper and documented why unsigned Debug
  launches can repeatedly prompt for SIP credential Keychain access.
- Added direct hardware keyboard support for the SwiftUI keypad and bumped
  the build number to 157.
- Moved active outgoing call controls into the SwiftUI keypad, including
  DTMF entry, duration, mute, and hang-up controls, and bumped the build
  number to 156.
- Removed decorative traffic-light dots from the SwiftUI sidebar.
- Collapsed the legacy account input and call-history views beneath the
  SwiftUI shell to prevent the old token-field focus ring showing through.
- Fixed UseCases receipt-localization bundle lookup after the SIPMan
  bundle identifier rename.
- Renamed the Xcode project and app product to SIPMan, refreshed the app
  icon, updated visible app strings, and bumped the build number to 155.
- Documented the SwiftUI softphone shell and active-call stats panel.
- Added an active-call panel with collapsible PJSIP debug stats in the
  SwiftUI softphone shell.
- Added a SwiftUI settings and diagnostics store for account registration,
  transport, and SIP troubleshooting details.
- Added a SwiftUI SIP MESSAGE screen backed by the SIP MESSAGE record and
  conversation models.
- Replaced the SwiftUI history placeholder with real call-history rows
  backed by the existing account history API.
- Wired the SwiftUI keypad to the existing outbound call path and added
  dial-pad behavior tests.
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
