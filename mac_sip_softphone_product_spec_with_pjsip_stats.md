# Mac SIP Softphone UI Specification

## 1. Purpose

This document describes the initial user interface and functional scope for a simple Mac SIP softphone application. The product should feel like a lightweight native macOS utility: clean, compact, calm, and focused on the minimum actions needed to place SIP calls, send messages, review call history, configure a SIP account, and support engineering diagnostics.

The current HTML mockup should be treated as the visual reference for layout, spacing, hierarchy, and interaction style.

This revision also incorporates implementation guidance for **in-call PJSIP/PJSUA2 statistics**, based on the debug call stats currently surfaced by the Umony iOS app.

## 2. Design Principles

The application should follow these principles:

- **Minimal visible complexity**: only expose the controls required for the current task.
- **Native Mac feel**: use macOS-like window styling, system typography, soft translucency, compact controls, and familiar left-hand navigation.
- **No heavy card nesting**: screens should use the available space directly. Avoid panels inside panels unless they provide clear functional separation.
- **Status always visible**: SIP registration state and active user number should be visible in the top-right status area.
- **Engineer-friendly diagnostics**: SIP diagnostics should be available, but not dominant in the main user flow.
- **Keypad-first workflow**: the default screen is the dialler/keypad.
- **Plain diagnostic output where useful**: SIP and media debug information should be easy to copy, screenshot, export, and reason about.

## 3. Overall Application Shell

### 3.1 Window Layout

The application uses a single-window layout with:

- A left navigation sidebar.
- A top status bar.
- A main content area.

The app shell should have:

- Rounded macOS-style outer window corners.
- Soft translucent background treatment.
- Subtle shadow around the whole application window.
- A light, cool grey/white visual palette.
- macOS traffic-light controls at top-left for visual familiarity.

### 3.2 Sidebar

The sidebar is the primary navigation element.

It contains:

1. macOS-style traffic lights.
2. A sidebar collapse button.
3. Product branding.
4. Primary navigation items.

Navigation items:

- **Keypad**
- **Messages**
- **History**
- **Settings**

The sidebar should be collapsible:

- Expanded width: approximately `236px`.
- Collapsed width: approximately `76px`.
- In collapsed state, icons remain visible and labels are hidden.
- The transition should be smooth and unobtrusive.

### 3.3 Top Status Bar

The top status bar is intentionally minimal.

It should show, aligned right:

- SIP registration state, for example `Registered` with a green presence dot.
- The active assigned number, for example `+44 20 7946 0000`.

The top bar should not show duplicate screen titles such as “Keypad” or “Ready to call”. Navigation state is already clear from the selected sidebar item.

## 4. Screens

## 4.1 Keypad Screen

### Purpose

The Keypad screen is the default screen. It allows a user to enter a telephone number and place an outbound SIP call.

### Layout

The keypad is centred in the main content area and intentionally compact.

It contains:

1. Number display field.
2. Standard twelve-button dial pad.
3. Call action row.

### Number Display

The number display should show:

- Placeholder text: `Enter number` when empty.
- The currently entered digits once the user starts typing.

Expected behaviour:

- Pressing keypad buttons appends digits to the number field.
- Delete removes the last character.
- Clear removes the whole number.

### Dial Pad

The dial pad should use a standard 3 x 4 layout:

| Row | Keys |
|---|---|
| 1 | `1`, `2 ABC`, `3 DEF` |
| 2 | `4 GHI`, `5 JKL`, `6 MNO` |
| 3 | `7 PQRS`, `8 TUV`, `9 WXYZ` |
| 4 | `*`, `0 +`, `#` |

Each key should have:

- Large primary digit/symbol.
- Optional small letter group.
- Soft rounded shape.
- Subtle hover/press feedback.

### Call Action Row

The bottom row contains:

- **Clear** button.
- Primary green **Call** button.
- **Delete** button.

Functional expectations:

- `Call` initiates an outbound SIP call to the currently entered number.
- `Clear` clears all input.
- `Delete` backspaces one character.
- If the number field is empty, `Call` should be disabled or should do nothing with a lightweight validation hint.

## 4.2 Messages Screen

### Purpose

The Messages screen provides a simple two-column messaging interface.

This is intended for SIP/SMS-style messaging or future message transport support. The UI should not assume a complex consumer messaging product; it should remain functional and enterprise-simple.

### Layout

The screen uses two columns:

- Left column: conversation list.
- Right column: active conversation.

The design should avoid enclosing these columns in visible outer panels. Dividers, headers, and row treatments are enough to define structure.

### Conversation List

The left column contains:

- Search field.
- Scrollable conversation list.

Each conversation item should include:

- Avatar or initials.
- Contact/display name.
- Last message timestamp.
- Last message preview.

Selected conversation behaviour:

- The selected conversation should have a subtle highlighted background.
- Only one conversation is active at a time.

### Active Conversation

The right column contains:

1. Conversation header.
2. Message transcript.
3. Composer.

#### Header

The header should show:

- Contact initials/avatar.
- Contact name.
- Contact phone number.
- A secondary `Call` button.

The `Call` button should initiate a call to that contact/number.

#### Message Transcript

Message bubbles should be visually distinct:

- Inbound messages: left aligned, light background.
- Outbound messages: right aligned, blue background.

The transcript should scroll vertically.

#### Composer

The composer should include:

- Single-line text input.
- Send button.

Expected behaviour:

- Typing into composer prepares an outbound message.
- Send dispatches the message to the active conversation.
- Empty messages should not be sent.

## 4.3 History Screen

### Purpose

The History screen shows inbound and outbound SIP call history.

### Layout

The screen should use the main content area directly, not a nested panel.

It contains:

1. Header row.
2. Call type filter.
3. Scrollable call history list.

### Header

The header should show:

- Title: `History`.
- Supporting text: `Inbound and outbound SIP call history.`

### Filters

A segmented control should allow filtering by:

- `All`
- `Inbound`
- `Outbound`

Future filter options may include:

- Missed
- Today
- This week
- Search by number/contact

### Call History Rows

Each call row should include:

- Direction/status icon.
- Contact name or `Unknown caller`.
- Phone number.
- Direction label: inbound, outbound, missed inbound.
- Date/time.
- Duration where available.
- Quick call-back action.

Example row data:

```text
Outbound · +44 7700 900123 · Today, 10:44 · 03:21
Inbound · +44 7700 900456 · Today, 09:15 · 11:08
Missed inbound · +44 20 7946 0172 · Yesterday, 16:32
```

Expected behaviour:

- Clicking a call row may open call details in future.
- Clicking the call button immediately calls the associated number.
- Missed calls should be visually distinguishable, using a red/missed icon treatment.

## 4.4 Settings Screen

### Purpose

The Settings screen provides account configuration and engineering diagnostics.

It should be functional and compact. Settings should not be overly nested.

### Layout

Settings uses a two-column layout on desktop-sized windows:

- Left column: **Account**.
- Right column: **Diagnostics**.

On smaller windows, these sections may stack vertically.

## 4.4.1 Account Section

### Purpose

The Account section configures the SIP account used for calls and messages.

### Fields

The initial Account section includes:

| Field | Type | Notes |
|---|---|---|
| Username | Text input | SIP username / auth username. |
| Password | Password input | SIP password / auth password. |
| Domain | Text input | SIP registrar/domain. |
| Transport | Select | `UDP`, `TCP`, `TLS`. |
| Port | Text input or numeric input | Defaults based on transport where possible. |

### Actions

The Account section includes:

- **Test registration**
- **Save changes**

Expected behaviour:

- `Save changes` persists account settings.
- `Test registration` attempts SIP registration using the current form values.
- The top-right registration status should update based on actual registration state.
- Validation should be lightweight and inline.

### Validation Expectations

Minimum validation:

- Username is required.
- Password is required.
- Domain is required.
- Transport must be one of `UDP`, `TCP`, `TLS`.
- Port must be valid if manually specified.

Suggested default ports:

| Transport | Default Port |
|---|---:|
| UDP | 5060 |
| TCP | 5060 |
| TLS | 5061 |

## 4.4.2 Diagnostics Section

### Purpose

Diagnostics provides basic SIP registration and troubleshooting information for engineers and support users.

This section is not intended to be the primary user workflow, but it should be easy to access when diagnosing SIP registration or call setup issues.

### Diagnostic Summary Tiles

Initial diagnostic tiles:

| Tile | Example | Notes |
|---|---|---|
| Registration | `200 OK` | Latest registration result. |
| Last registered | `10:41:22` | Timestamp of last successful registration. |
| Transport | `TLS · 5061` | Current SIP transport and port. |

Possible future diagnostic fields:

- Registrar address.
- Local SIP socket.
- Public IP / NAT detected state.
- Contact URI.
- Expiry interval.
- Last registration failure reason.
- TLS certificate validation state.
- DNS/SRV resolution result.

### SIP Log

The Diagnostics section includes a rolling SIP log.

UI requirements:

- Dark terminal-style display.
- Monospace font.
- Scrollable.
- Shows recent SIP signalling lines.
- Header should show `Rolling SIP log` and the current retention window, for example `Last 250 lines`.
- Include an `Export SIP log` action.

Example log format:

```text
10:41:21.104 → REGISTER sip:sip.example.com SIP/2.0
10:41:21.138 ← SIP/2.0 401 Unauthorized
10:41:21.142 → REGISTER sip:sip.example.com SIP/2.0
10:41:21.188 ← SIP/2.0 200 OK
10:42:03.021 → OPTIONS sip:sip.example.com SIP/2.0
10:42:03.044 ← SIP/2.0 200 OK
10:44:10.502 → INVITE sip:+447700900123@sip.example.com SIP/2.0
```

Implementation notes:

- SIP log should be a rolling in-memory window initially.
- Default window: last 250 lines.
- Export should produce a text file suitable for support/debugging.
- Consider redacting sensitive headers or credentials before display/export.
- Engineers should be able to copy/select log text.

## 4.5 In-Call Screen and Debug Call Stats

### Purpose

The application should support a simple in-call state once a call is active. The normal user-facing in-call UI should remain minimal, but the app should also support an engineer-facing **debug call stats** view for PJSIP/PJSUA2 media diagnostics.

This debug view is based on the in-call statistics currently surfaced by the Umony iOS app when `Show debug call stats` is enabled.

### Default In-Call UI

The default in-call UI should show only essential call controls and status:

- Remote party name or number.
- Call state, for example `Calling`, `Ringing`, `Connected`, `Ended`, `Failed`.
- Call duration once connected.
- Mute.
- Keypad/DTMF.
- End call.
- Optional hold if implemented.

The debug stats table should be hidden by default.

### Debug Stats Visibility

The debug stats table should be shown only when one of the following is true:

- A user/developer setting such as `Show debug call stats` is enabled.
- A debug/development build enables it by default.
- An environment/configuration flag enables it for support or QA.

When debug stats are visible, the call UI should show a live table above or below the core in-call controls.

### Debug Stats Refresh

The live table is built from one tab-separated debug string returned by the native PJSUA2 bridge once a call has active audio media.

Requirements:

- Refresh once per second.
- Display columns: `Metric`, `Live`, `Peak`.
- `Live` is the current value.
- `Peak` is maintained by the UI for any row whose live value starts with a number.
- Peak handling should use a simple numeric parse of the displayed string.
- Example: `316.0 ms` peaks as `316.0 ms`.
- Non-numeric rows should show no peak.

Table header:

```text
Metric  Live  Peak
```

### Native Source Data

The native bridge should use the first audio media stream in the active call.

Source APIs:

| Source | Purpose |
|---|---|
| `Call::getStreamInfo(mediaIndex)` | Codec, media direction, payload types, negotiated remote RTP/RTCP addresses. |
| `Call::getStreamStat(mediaIndex)` | RTCP, RTT, and jitter-buffer counters. |
| `Call::getMedTransportInfo(mediaIndex)` | Local RTP/RTCP socket names and source RTP/RTCP addresses. |
| `pjsua_call_get_med_transport_info()` | PJSUA media transport info. |
| `pjmedia_transport_info_get_spc_info(..., PJMEDIA_TRANSPORT_TYPE_ICE)` | ICE candidate-pair details. |
| Parsed SIP offer/answer SDP | Local and remote advertised RTP, RTCP, and ICE candidates. |

### App-Level Debug Row

The UI prepends one app-level row:

| Row | Meaning | Calculation/source |
|---|---|---|
| `Connection` | Current app network policy transport. | `Wi-Fi`, `Cellular`, `Unavailable`, or `Other` from the app's network policy snapshot. |

For the Mac app, this should map to the app's active network interface or network policy abstraction. For example, `Wi-Fi`, `Ethernet`, `Unavailable`, or `Other` may be more appropriate on desktop.

### Native PJSIP Debug Rows

The debug table should support the following rows.

| Row | Meaning | Calculation/source |
|---|---|---|
| `Codec` | Active audio codec and clock rate. | `StreamInfo.codecName` plus `StreamInfo.codecClockRate`, formatted like `opus / 48000 Hz`. |
| `Local SDP RTP` | RTP address advertised by local SDP. | Parse the audio `m=` port and audio-level `c=` address, falling back to session `c=`. |
| `Local SDP RTCP` | RTCP address advertised by local SDP. | Parse audio `a=rtcp:`. If the attribute omits an address, use the SDP connection address. |
| `Local SDP ICE` | Local ICE candidates advertised in SDP. | Parse audio `a=candidate:` lines and deduplicate summaries as `<type> <address>:<port>`, for example `srflx 203.0.113.5:62000`. |
| `Local SDP address warning` | Local SDP includes private or local addresses. | Added when advertised RTP/RTCP/ICE addresses are private IPv4, loopback, link-local IPv4, IPv6 loopback, IPv6 link-local, or IPv6 ULA. |
| `Remote SDP RTP` | RTP address advertised by remote SDP. | Same parsing as local SDP, using received INVITE/200 OK SDP. |
| `Remote SDP RTCP` | RTCP address advertised by remote SDP. | Same parsing as local SDP. |
| `Remote SDP ICE` | Remote ICE candidates advertised in SDP. | Same parsing as local SDP. |
| `Remote SDP address warning` | Remote SDP includes private or local addresses. | Same private/local checks as local SDP. |
| `Local RTP` | Actual local RTP transport address. | `MediaTransportInfo.localRtpName`; display `unavailable` if empty. |
| `Local RTCP` | Actual local RTCP transport address. | `MediaTransportInfo.localRtcpName`; display `unavailable` if empty. |
| `Remote RTP` | Negotiated remote RTP target. | `StreamInfo.remoteRtpAddress`; display `unavailable` if empty. |
| `Remote RTCP` | Negotiated remote RTCP target. | `StreamInfo.remoteRtcpAddress`; display `unavailable` if empty. |
| `Selected RTP destination` | The RTP address PJSIP is sending to. | Currently same value as `Remote RTP`; keep separate for ICE/NAT diagnostics readability. |
| `Source RTP` | Source address from which RTP is being received. | `MediaTransportInfo.srcRtpName`; useful for symmetric RTP/NAT checks. |
| `Source RTCP` | Source address from which RTCP is being received. | `MediaTransportInfo.srcRtcpName`. |
| `ICE info` | Error row when media transport info cannot be fetched. | `unavailable status=<pj_status_t>` if `pjsua_call_get_med_transport_info()` fails. |
| `ICE active` | Whether the PJSIP ICE transport is active. | `pjmedia_ice_transport_info.active`; if there is no ICE-specific transport info, show `false`. |
| `ICE state` | Current ICE session state. | `pj_ice_strans_state_name(sess_state)`, for example `Negotiation Success`. |
| `ICE role` | ICE role. | `pj_ice_sess_role_name(role)`, for example `Controlled` or `Controlling`. |
| `ICE RTP pair` | Selected ICE candidate pair for RTP. | Format component 0 as `local <type> <addr> -> remote <type> <addr>`. |
| `ICE RTP path type` | Human-friendly path classification for RTP. | `relay` if either candidate is relayed; `direct NAT` if either candidate is server-reflexive or peer-reflexive; otherwise `direct host`. |
| `ICE RTCP pair` | Selected ICE candidate pair for RTCP. | Same as RTP, but component 1. Only shown when ICE has more than one component. With RTCP mux this row is usually absent. |
| `ICE RTCP path type` | Human-friendly path classification for RTCP. | Same classification as RTP, for component 1. |
| `TURN used` | Whether the selected ICE pair uses a TURN relay. | `true` if any selected ICE component has a local or remote relayed candidate; otherwise `false`. If no ICE transport info, show `false`. |
| `TURN transport` | TURN transport type. | Currently `UDP` when `TURN used` is true, otherwise `not used`. |
| `TURN server` | Configured TURN server. | Shown only when TURN is used and the app has a non-empty TURN server config. |
| `ICE log tail` | Recent ICE log summary. | Optional diagnostic row behind an app setting/env gate. |
| `Network changes` | Network transport changes during the call. | App-maintained JSON event list. Events include transport, timestamp, and selected media probe fields such as `rx`, `tx`, `rl`, `tl`, `rtt`, and `ice`. |
| `Audio path changes` | Audio route changes during the call. | App-maintained JSON event list, for example speaker/receiver transitions. |
| `RX packets` | RTP/RTCP receive packet count. | `StreamStat.rtcp.rxStat.pkt`. |
| `RX bytes` | Receive payload byte count. | `StreamStat.rtcp.rxStat.bytes`. |
| `RX loss` | Receive-side lost packet count. | `StreamStat.rtcp.rxStat.loss`. |
| `RX jitter` | Last receive jitter sample. | `StreamStat.rtcp.rxStat.jitterUsec.last / 1000`, formatted to one decimal place in milliseconds. |
| `SRTP auth failures` | Count of SRTP authentication failures for the current call. | App-maintained atomic counter reset at call start. |
| `TX packets` | Transmit RTCP packet count reported by PJSIP. | `StreamStat.rtcp.txStat.pkt`. |
| `TX bytes` | Transmit payload byte count. | `StreamStat.rtcp.txStat.bytes`. |
| `TX loss` | Packet loss reported for the transmit direction. | `StreamStat.rtcp.txStat.loss`. This reflects RTCP feedback from the far end, not local capture loss. |
| `TX jitter` | Last transmit-direction jitter sample reported by RTCP. | `StreamStat.rtcp.txStat.jitterUsec.last / 1000`, formatted to one decimal place in milliseconds. |
| `RTT` | Last round-trip time sample. | `StreamStat.rtcp.rttUsec.last / 1000`, formatted to one decimal place in milliseconds. |
| `JBuf avg` | Average jitter-buffer delay. | `StreamStat.jbuf.avgDelayMsec`, formatted as milliseconds. |
| `JBuf lost` | Jitter-buffer lost frame count. | `StreamStat.jbuf.lost`. |
| `JBuf discard` | Jitter-buffer discard count. | `StreamStat.jbuf.discard`. |
| `JBuf empty` | Jitter-buffer empty count. | `StreamStat.jbuf.empty`. |

### Call Quality Indicator

The app should use the same rows for a small live quality indicator.

When debug stats are hidden:

- Show a debounced user-facing call quality banner only when useful.
- Avoid flicker and avoid alarming users over single transient samples.

When debug stats are visible:

- Show one of the following labels above the table:
  - `Quality: Waiting`
  - `Quality: Good`
  - `Quality: Fair`
  - `Quality: Poor`

### Current Quality Thresholds

| Signal | Fair | Poor |
|---|---:|---:|
| `RTT` | `>= 150 ms` | `>= 300 ms` |
| `JBuf avg` | `>= 120 ms` | `>= 250 ms` |
| `RX jitter` | `>= 25 ms` | `>= 60 ms` |
| `JBuf lost` delta | Repeated positive deltas | Repeated deltas `>= 3` |
| `JBuf discard` delta | Repeated positive deltas | Repeated deltas `>= 3` |
| `JBuf empty` delta | Repeated positive deltas | Repeated deltas `>= 2` |

For jitter-buffer lost/discard/empty:

- Compare the current cumulative counter with the previous one-second sample.
- A single event is often concealed by the codec.
- Promote these buffer events only after at least two samples of the same event type within a five-second window.
- The non-debug quality banner should wait two seconds before displaying a fair/poor state.

### Practical PJSIP Implementation Guidance

The Mac implementation should preserve the lessons from the existing Umony iOS implementation:

- Keep raw PJSIP counters and displayed labels close together.
- Keep the debug table deliberately plain because it is often copied from screenshots or logs.
- Preserve both SDP-advertised addresses and PJSIP active transport addresses.
- Differences between `Local SDP RTP`, `Local RTP`, `Source RTP`, and the selected ICE pair are often the clue for NAT/TURN issues.
- Classify the selected ICE path into `direct host`, `direct NAT`, or `relay`.
- Show cumulative counters, but assess quality from deltas where the counter can naturally grow over the call, especially `JBuf lost`, `JBuf discard`, and `JBuf empty`.
- Do not overreact to a single jitter-buffer event.
- Use the last RTCP `MathStat` value in the live UI because it maps to what the user is experiencing now.
- Preserve a peak column to make transient spikes obvious.

## 5. Navigation Behaviour

Primary navigation is controlled by the sidebar.

Expected behaviour:

- Default selected screen: **Keypad**.
- Selecting a sidebar item switches the main content area.
- Active navigation item is highlighted.
- Sidebar collapse state should preserve the active selection.
- Collapsed sidebar should remain usable via icons.

Initial tabs/screens:

| Nav Item | Screen ID | Purpose |
|---|---|---|
| Keypad | `keypad` | Dial outbound calls. |
| Messages | `messages` | View and send messages. |
| History | `history` | View inbound/outbound call history. |
| Settings | `settings` | Configure SIP account and diagnostics. |

The in-call UI is not a permanent sidebar item. It is a transient call state shown when a call is active.

## 6. Visual Design System

### Typography

Use the macOS system font stack:

```css
-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Arial, sans-serif
```

### Colours

Primary palette:

| Token | Value | Usage |
|---|---|---|
| Text | `#151923` | Main text. |
| Muted text | `#6d7480` | Secondary labels. |
| Muted light | `#9aa2ad` | Placeholders and metadata. |
| Blue | `#0a84ff` | Primary action / outbound messages. |
| Green | `#30d158` | Registered / call action. |
| Red | `#ff453a` | Missed/error state. |
| Line | `rgba(80, 90, 110, 0.14)` | Dividers. |

### Shape

The UI should use rounded controls:

- Main window: large radius.
- Buttons/inputs: medium-large radius.
- Avatars: rounded squares.
- Pills: fully rounded.

### Surfaces

Use subtle translucent surfaces sparingly.

Important instruction: avoid visible nested cards/panels around Messaging, History, and Settings sections. The main app shell already provides the container. Use rows, dividers, controls, and section headers instead of additional panel boxes.

## 7. Core Interaction Requirements

## 7.1 Registration State

The app should expose a simple top-level registration status.

Initial states:

| State | Display |
|---|---|
| Registered | Green dot + `Registered` |
| Registering | Neutral/amber dot + `Registering` |
| Failed | Red dot + `Registration failed` |
| Offline | Muted dot + `Offline` |

The status should be visible in the top-right of the app at all times.

## 7.2 Calling

Minimum call initiation paths:

- Keypad → Call button.
- Messages → active contact Call button.
- History → call-back button.

Minimum call states:

- Dialling.
- Ringing.
- Connected.
- Ended.
- Failed.

The active call view should support debug stats when enabled.

## 7.3 Messaging

Minimum messaging behaviour:

- List conversations.
- Select conversation.
- View message transcript.
- Send outbound message.
- Search conversations.

The current mockup assumes one active conversation at a time.

## 7.4 Call History

Minimum call history behaviour:

- Show recent calls.
- Distinguish inbound, outbound, and missed calls.
- Filter by all/inbound/outbound.
- Call back from a history row.

## 7.5 SIP Diagnostics

Minimum diagnostics behaviour:

- Show latest registration status.
- Show last successful registration timestamp.
- Show current transport and port.
- Show rolling SIP log.
- Export SIP log.

## 7.6 In-Call Media Diagnostics

Minimum in-call media diagnostics behaviour:

- Collect PJSIP/PJSUA2 stream info once active audio media exists.
- Refresh the debug table once per second.
- Show `Metric`, `Live`, and `Peak` columns.
- Maintain peaks for numeric live values.
- Show call quality status when debug stats are enabled.
- Support a debounced non-debug quality banner.
- Preserve SDP, RTP/RTCP, ICE, TURN, RTCP, RTT, jitter, SRTP, and jitter-buffer rows as described above.

## 8. Data Model Suggestions

### 8.1 SIP Account

```ts
interface SipAccountSettings {
  username: string;
  password: string;
  domain: string;
  transport: 'UDP' | 'TCP' | 'TLS';
  port: number;
}
```

### 8.2 Registration State

```ts
interface SipRegistrationState {
  status: 'registered' | 'registering' | 'failed' | 'offline';
  statusText: string;
  lastRegisteredAt?: string;
  lastFailureReason?: string;
  transport: 'UDP' | 'TCP' | 'TLS';
  port: number;
}
```

### 8.3 Conversation

```ts
interface ConversationSummary {
  id: string;
  displayName: string;
  phoneNumber: string;
  initials?: string;
  lastMessagePreview: string;
  lastMessageAt: string;
  unreadCount?: number;
}
```

### 8.4 Message

```ts
interface Message {
  id: string;
  conversationId: string;
  direction: 'inbound' | 'outbound';
  body: string;
  timestamp: string;
  status?: 'sending' | 'sent' | 'failed';
}
```

### 8.5 Call History Item

```ts
interface CallHistoryItem {
  id: string;
  direction: 'inbound' | 'outbound';
  status: 'answered' | 'missed' | 'failed';
  displayName?: string;
  phoneNumber: string;
  startedAt: string;
  durationSeconds?: number;
}
```

### 8.6 SIP Log Line

```ts
interface SipLogLine {
  id: string;
  timestamp: string;
  direction: 'inbound' | 'outbound';
  summary: string;
  raw?: string;
}
```

### 8.7 Active Call

```ts
interface ActiveCallState {
  callId: string;
  remoteDisplayName?: string;
  remoteNumber: string;
  state: 'dialling' | 'ringing' | 'connected' | 'ended' | 'failed';
  startedAt?: string;
  connectedAt?: string;
  endedAt?: string;
  muted: boolean;
  held?: boolean;
  quality: 'waiting' | 'good' | 'fair' | 'poor';
  debugStatsVisible: boolean;
}
```

### 8.8 In-Call Debug Stat Row

```ts
interface CallDebugStatRow {
  metric: string;
  live: string;
  peak?: string;
  numericLiveValue?: number;
  updatedAt: string;
}
```

### 8.9 In-Call Quality State

```ts
interface CallQualityState {
  quality: 'waiting' | 'good' | 'fair' | 'poor';
  rttMs?: number;
  rxJitterMs?: number;
  jbufAvgMs?: number;
  jbufLostDelta?: number;
  jbufDiscardDelta?: number;
  jbufEmptyDelta?: number;
  lastEvaluatedAt: string;
}
```

## 9. Engineering Implementation Notes

### 9.1 Suggested Component Breakdown

Suggested top-level components:

```text
AppShell
├── Sidebar
│   ├── WindowControls
│   ├── Brand
│   └── Navigation
├── TopStatusBar
└── MainContent
    ├── KeypadScreen
    ├── MessagesScreen
    │   ├── ConversationList
    │   ├── ConversationHeader
    │   ├── MessageTranscript
    │   └── MessageComposer
    ├── HistoryScreen
    │   ├── HistoryFilter
    │   └── CallHistoryList
    ├── SettingsScreen
    │   ├── AccountSettings
    │   └── Diagnostics
    │       ├── DiagnosticTiles
    │       └── SipLogViewer
    └── InCallView
        ├── CallHeader
        ├── CallControls
        ├── CallQualityIndicator
        └── DebugCallStatsTable
```

### 9.2 State Management

Minimum app state:

```ts
type ActiveView = 'keypad' | 'messages' | 'history' | 'settings';

interface AppState {
  activeView: ActiveView;
  sidebarCollapsed: boolean;
  dialledNumber: string;
  activeConversationId?: string;
  historyFilter: 'all' | 'inbound' | 'outbound';
  accountSettings: SipAccountSettings;
  registrationState: SipRegistrationState;
  activeCall?: ActiveCallState;
  debugCallStats: CallDebugStatRow[];
  callQuality?: CallQualityState;
}
```

### 9.3 Persistence

Suggested persistence:

- SIP account settings: secure local storage / keychain for credentials.
- Non-sensitive preferences: local config file or app settings store.
- Sidebar collapsed state: local preference.
- `Show debug call stats`: local developer/support preference.
- SIP logs: initially memory-only rolling buffer; export on demand.
- In-call debug stats: live only by default; export/snapshot only if explicitly required.

Passwords should not be stored in plain text.

### 9.4 Accessibility

Minimum accessibility requirements:

- Buttons should have accessible labels.
- Keypad buttons should be keyboard accessible.
- Active navigation state should be programmatically indicated.
- Inputs should have labels.
- Colour should not be the only indication of error/status.
- SIP log should support text selection and copying.
- Debug call stats should be readable as a semantic table.

### 9.5 Keyboard Behaviour

Recommended keyboard support:

- Numeric keyboard input on Keypad screen should append digits.
- Backspace should delete the last digit.
- Enter should initiate call if a valid number is present.
- Escape may clear the current input or return focus depending on context.
- Cmd+1 / Cmd+2 / Cmd+3 / Cmd+4 may switch between Keypad, Messages, History, Settings.
- During an active call, keyboard shortcuts for mute/end call may be considered but must avoid accidental hangups.

### 9.6 Native Bridge Considerations

The desktop app should expose a native bridge from the UI layer to the PJSIP/PJSUA2 layer for:

- SIP account registration.
- Outbound call initiation.
- Call state events.
- Media active events.
- SIP log events.
- In-call debug stats string.
- Call quality state.

The debug stats bridge may initially return a tab-separated string, matching the iOS implementation, but the UI layer should parse it into structured rows for rendering and peak calculation.

## 10. Out of Scope for Initial Build

The following are intentionally out of scope for the first UI pass unless separately prioritised:

- Call transfer.
- Conference calling.
- Contact/address book integration.
- Voicemail.
- Advanced audio device selection.
- Advanced SIP account options.
- Multiple SIP accounts.
- Message delivery receipts.
- Attachments/MMS.
- Dark mode.
- Full packet-level SIP trace viewer with expandable messages.

The following is now **in scope at implementation/spec level**, even if the first visual mockup does not yet fully show it:

- Minimal in-call UI.
- Optional debug in-call PJSIP statistics table.
- Live call quality indicator based on PJSIP/RTCP/jitter-buffer metrics.

## 11. Initial Acceptance Criteria

The first engineering implementation should satisfy the following:

1. App opens to the **Keypad** screen by default.
2. Sidebar contains **Keypad**, **Messages**, **History**, and **Settings**.
3. Sidebar can be collapsed and expanded.
4. Top-right status shows SIP registration state and assigned number.
5. Keypad accepts digit input and supports clear/delete.
6. Messages screen shows a two-column conversation layout.
7. History screen shows inbound, outbound, and missed call rows.
8. Settings screen shows Account and Diagnostics sections.
9. Account settings include username, password, domain, transport, and port.
10. Diagnostics show registration state, last registered time, transport, and rolling SIP log.
11. SIP log can be exported.
12. UI avoids unnecessary nested panels inside the main content area.
13. The implementation matches the general look and layout of the HTML mockup.
14. Active calls enter a minimal in-call state.
15. In-call debug stats can be enabled through a debug/support setting.
16. In-call debug stats refresh once per second after active audio media exists.
17. In-call debug stats show `Metric`, `Live`, and `Peak` columns.
18. Numeric live values maintain a peak value in the UI.
19. In-call quality state supports `Waiting`, `Good`, `Fair`, and `Poor`.
20. Quality thresholds match the values in this document unless deliberately revised.
21. SDP, RTP/RTCP, ICE, TURN, RTCP, RTT, SRTP, and jitter-buffer diagnostic rows are available from the PJSIP bridge where supported.

## 12. Open Questions

The engineering team should confirm the following before implementation:

1. Which SIP stack/library will be used in the Mac app?
2. Will credentials be stored in macOS Keychain?
3. Should the app support only one SIP account initially?
4. Should SIP logging be enabled by default or only when diagnostics are opened?
5. Should exported SIP logs be redacted automatically?
6. What number formatting rules should be applied before dialling?
7. Should messages be SIP SIMPLE, SMS-backed, or abstracted behind a backend API?
8. Should call history be local-only or synchronised with a backend?
9. Should the left sidebar collapse state persist across app restarts?
10. Should there be a visible registration failure banner, or is the top-right status enough for v1?
11. Should `Show debug call stats` appear in Settings, or remain hidden behind a developer/support flag?
12. Should call quality warnings be visible to all users, or only support/debug users?
13. Should the desktop implementation keep the same tab-separated debug string format as iOS, or return structured JSON rows from the native bridge?
14. Should the Mac app include Ethernet-specific connection labelling in addition to Wi-Fi/Other?
15. Should SIP/media diagnostics be exportable together as one support bundle?

