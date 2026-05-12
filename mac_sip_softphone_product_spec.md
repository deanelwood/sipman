# Mac SIP Softphone UI Specification

## 1. Purpose

This document describes the initial user interface and functional scope for a simple Mac SIP softphone application. The product should feel like a lightweight native macOS utility: clean, compact, calm, and focused on the minimum actions needed to place SIP calls, send messages, review call history, and configure a SIP account.

The current HTML mockup should be treated as the visual reference for layout, spacing, hierarchy, and interaction style.

## 2. Design Principles

The application should follow these principles:

- **Minimal visible complexity**: only expose the controls required for the current task.
- **Native Mac feel**: use macOS-like window styling, system typography, soft translucency, compact controls, and familiar left-hand navigation.
- **No heavy card nesting**: screens should use the available space directly. Avoid panels inside panels unless they provide clear functional separation.
- **Status always visible**: SIP registration state and active user number should be visible in the top-right status area.
- **Engineer-friendly diagnostics**: SIP diagnostics should be available, but not dominant in the main user flow.
- **Keypad-first workflow**: the default screen is the dialler/keypad.

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

Future call states may include:

- Dialling.
- Ringing.
- In call.
- Muted.
- On hold.
- Call ended.
- Failed.

These are out of current visual scope but should be considered in architecture.

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
    └── SettingsScreen
        ├── AccountSettings
        └── Diagnostics
            ├── DiagnosticTiles
            └── SipLogViewer
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
}
```

### 9.3 Persistence

Suggested persistence:

- SIP account settings: secure local storage / keychain for credentials.
- Non-sensitive preferences: local config file or app settings store.
- Sidebar collapsed state: local preference.
- SIP logs: initially memory-only rolling buffer; export on demand.

Passwords should not be stored in plain text.

### 9.4 Accessibility

Minimum accessibility requirements:

- Buttons should have accessible labels.
- Keypad buttons should be keyboard accessible.
- Active navigation state should be programmatically indicated.
- Inputs should have labels.
- Colour should not be the only indication of error/status.
- SIP log should support text selection and copying.

### 9.5 Keyboard Behaviour

Recommended keyboard support:

- Numeric keyboard input on Keypad screen should append digits.
- Backspace should delete the last digit.
- Enter should initiate call if a valid number is present.
- Escape may clear the current input or return focus depending on context.
- Cmd+1 / Cmd+2 / Cmd+3 / Cmd+4 may switch between Keypad, Messages, History, Settings.

## 10. Out of Scope for Initial Build

The following are intentionally out of scope for the first UI pass unless separately prioritised:

- Full in-call UI.
- Call transfer, hold, mute, conference.
- Contact/address book integration.
- Voicemail.
- Audio device selection.
- Advanced SIP account options.
- Multiple SIP accounts.
- Message delivery receipts.
- Attachments/MMS.
- Dark mode.
- Full SIP trace viewer with packet expansion.

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

