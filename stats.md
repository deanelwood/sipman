# In-call PJSIP stats used by Umony

This note documents the in-call stats currently surfaced by the Umony iOS app
when `Show debug call stats` is enabled. It is intended as implementation
guidance for another desktop app that also uses PJSIP/PJSUA2.

The live table is built from one tab-separated debug string returned by the
native PJSUA2 bridge once a call has active audio media. The UI refreshes it
once per second. In DEBUG builds the table shows:

```text
Metric  Live  Peak
```

`Live` is the current value. `Peak` is maintained in the UI for any row whose
live value starts with a number, using a simple numeric parse of the displayed
string. For example, `316.0 ms` peaks as `316.0 ms`; non-numeric rows show no
peak.

## Source data

The native bridge uses the first audio media stream in the active call:

- `Call::getStreamInfo(mediaIndex)` for codec, media direction, payload types,
  and negotiated remote RTP/RTCP addresses.
- `Call::getStreamStat(mediaIndex)` for RTCP, RTT, and jitter-buffer counters.
- `Call::getMedTransportInfo(mediaIndex)` for local RTP/RTCP socket names and
  source RTP/RTCP addresses.
- `pjsua_call_get_med_transport_info()` plus
  `pjmedia_transport_info_get_spc_info(..., PJMEDIA_TRANSPORT_TYPE_ICE)` for
  ICE candidate-pair details.
- Parsed SIP offer/answer SDP for local and remote advertised RTP, RTCP, and
  ICE candidates.

## Rows shown in the debug table

The UI prepends one app-level row:

| Row | Meaning | Calculation/source |
| --- | --- | --- |
| `Connection` | Current app network policy transport. | `Wi-Fi`, `Cellular`, `Unavailable`, or `Other` from the app's network policy snapshot. |

The native PJSIP rows are:

| Row | Meaning | Calculation/source |
| --- | --- | --- |
| `Codec` | Active audio codec and clock rate. | `StreamInfo.codecName` plus `StreamInfo.codecClockRate`, formatted like `opus / 48000 Hz`. |
| `Local SDP RTP` | RTP address advertised by our local SDP. | Parses the audio `m=` port and audio-level `c=` address, falling back to session `c=`. |
| `Local SDP RTCP` | RTCP address advertised by our local SDP. | Parses audio `a=rtcp:`. If the attribute omits an address, uses the SDP connection address. |
| `Local SDP ICE` | Local ICE candidates advertised in SDP. | Parses audio `a=candidate:` lines and deduplicates summaries as `<type> <address>:<port>`, for example `srflx 203.0.113.5:62000`. |
| `Local SDP address warning` | Local SDP includes private or local addresses. | Added when advertised RTP/RTCP/ICE addresses are private IPv4, loopback, link-local IPv4, IPv6 loopback, IPv6 link-local, or IPv6 ULA. |
| `Remote SDP RTP` | RTP address advertised by the remote SDP. | Same parsing as local SDP, using received INVITE/200 OK SDP. |
| `Remote SDP RTCP` | RTCP address advertised by the remote SDP. | Same parsing as local SDP. |
| `Remote SDP ICE` | Remote ICE candidates advertised in SDP. | Same parsing as local SDP. |
| `Remote SDP address warning` | Remote SDP includes private or local addresses. | Same private/local checks as local SDP. |
| `Local RTP` | Actual local RTP transport address. | `MediaTransportInfo.localRtpName`; displays `unavailable` if empty. |
| `Local RTCP` | Actual local RTCP transport address. | `MediaTransportInfo.localRtcpName`; displays `unavailable` if empty. |
| `Remote RTP` | Negotiated remote RTP target. | `StreamInfo.remoteRtpAddress`; displays `unavailable` if empty. |
| `Remote RTCP` | Negotiated remote RTCP target. | `StreamInfo.remoteRtcpAddress`; displays `unavailable` if empty. |
| `Selected RTP destination` | The RTP address PJSIP is sending to. | Currently the same value as `Remote RTP`. Keeping a separate row made ICE/NAT diagnostics easier to read. |
| `Source RTP` | Source address from which RTP is being received. | `MediaTransportInfo.srcRtpName`; useful for symmetric RTP/NAT checks. |
| `Source RTCP` | Source address from which RTCP is being received. | `MediaTransportInfo.srcRtcpName`. |
| `ICE info` | Error row when media transport info cannot be fetched. | `unavailable status=<pj_status_t>` if `pjsua_call_get_med_transport_info()` fails. |
| `ICE active` | Whether the PJSIP ICE transport is active. | `pjmedia_ice_transport_info.active`; if there is no ICE-specific transport info we show `false`. |
| `ICE state` | Current ICE session state. | `pj_ice_strans_state_name(sess_state)`, for example `Negotiation Success`. |
| `ICE role` | ICE role. | `pj_ice_sess_role_name(role)`, for example `Controlled` or `Controlling`. |
| `ICE RTP pair` | Selected ICE candidate pair for RTP. | Formats component 0 as `local <type> <addr> -> remote <type> <addr>`. |
| `ICE RTP path type` | Human-friendly path classification for RTP. | `relay` if either candidate is relayed; `direct NAT` if either candidate is server-reflexive or peer-reflexive; otherwise `direct host`. |
| `ICE RTCP pair` | Selected ICE candidate pair for RTCP. | Same as RTP, but component 1. Only shown when ICE has more than one component. With RTCP mux this row is usually absent. |
| `ICE RTCP path type` | Human-friendly path classification for RTCP. | Same classification as RTP, for component 1. |
| `TURN used` | Whether the selected ICE pair uses a TURN relay. | `true` if any selected ICE component has a local or remote relayed candidate; otherwise `false`. If there is no ICE transport info, we show `false`. |
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

## Call quality interpretation

The app uses the same rows for a small live quality indicator. When debug stats
are hidden, it shows a debounced banner. When debug stats are visible, it shows
`Quality: Waiting`, `Quality: Good`, `Quality: Fair`, or `Quality: Poor` above
the table.

The current thresholds are:

| Signal | Fair | Poor |
| --- | --- | --- |
| `RTT` | `>= 150 ms` | `>= 300 ms` |
| `JBuf avg` | `>= 120 ms` | `>= 250 ms` |
| `RX jitter` | `>= 25 ms` | `>= 60 ms` |
| `JBuf lost` delta | Repeated positive deltas | Repeated deltas `>= 3` |
| `JBuf discard` delta | Repeated positive deltas | Repeated deltas `>= 3` |
| `JBuf empty` delta | Repeated positive deltas | Repeated deltas `>= 2` |

For jitter-buffer lost/discard/empty, we compare the current cumulative counter
with the previous one-second sample. A single event is often concealed by the
codec, so the UI only promotes these buffer events after at least two samples of
the same event type within a five-second window. The non-debug quality banner
also waits two seconds before displaying a fair/poor state, to avoid flicker.

## Practical lessons for another PJSIP app

- Keep the raw PJSIP counters and the displayed labels close together. The table
  is deliberately plain because it is often copied from screenshots or logs.
- Preserve both SDP-advertised addresses and PJSIP's active transport addresses.
  The mismatch between `Local SDP RTP`, `Local RTP`, `Source RTP`, and the
  selected ICE pair is often the clue for NAT/TURN problems.
- Classify the selected ICE path into `direct host`, `direct NAT`, or `relay`;
  it is faster for support than reading candidate types by hand.
- Show cumulative counters, but assess quality from deltas where the counter can
  naturally grow over the call (`JBuf lost`, `discard`, `empty`).
- Do not overreact to a single jitter-buffer event. Waiting for repeated samples
  avoids warning users about artifacts the codec may already have concealed.
- Use the last RTCP `MathStat` value in the live UI. It maps to what the user is
  experiencing now, while the peak column still makes obvious spikes visible.
