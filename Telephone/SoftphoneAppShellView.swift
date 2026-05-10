//
//  SoftphoneAppShellView.swift
//  Telephone
//
//  Copyright © 2026 SIPMan
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import AppKit
import SwiftUI
import UseCases

@objc
@MainActor
protocol SoftphoneCallTarget: AnyObject {
    @objc(softphoneMakeCallTo:)
    func softphoneMakeCall(to destination: String)
    @objc(softphonePickCallHistoryRecordWithIdentifier:)
    func softphonePickCallHistoryRecord(withIdentifier identifier: String)
    @objc(softphoneHangUpCallWithIdentifier:)
    func softphoneHangUpCall(withIdentifier identifier: String)
    @objc(softphoneToggleMuteForCallWithIdentifier:)
    func softphoneToggleMuteForCall(withIdentifier identifier: String)
    @objc(softphoneSendDTMFDigit:forCallWithIdentifier:)
    func softphoneSendDTMFDigit(_ digit: String, forCallWithIdentifier identifier: String)
}

@objcMembers
final class SoftphoneAppShellViewFactory: NSObject {
    @MainActor
    @objc(makeViewWithCallTarget:accountDisplayName:sipAddress:callHistoryStore:messageStore:diagnosticsStore:activeCallStore:)
    static func makeView(
        callTarget: SoftphoneCallTarget,
        accountDisplayName: String,
        sipAddress: String,
        callHistoryStore: SoftphoneCallHistoryStore,
        messageStore: SoftphoneMessageStore,
        diagnosticsStore: SoftphoneDiagnosticsStore,
        activeCallStore: SoftphoneActiveCallStore
    ) -> NSView {
        let view = NSHostingView(
            rootView: SoftphoneAppShellView(
                accountDisplayName: accountDisplayName,
                sipAddress: sipAddress,
                callHistoryStore: callHistoryStore,
                messageStore: messageStore,
                diagnosticsStore: diagnosticsStore,
                activeCallStore: activeCallStore,
                onCall: { [weak callTarget] destination in
                    callTarget?.softphoneMakeCall(to: destination)
                },
                onPickCallHistoryRecord: { [weak callTarget] identifier in
                    callTarget?.softphonePickCallHistoryRecord(withIdentifier: identifier)
                },
                onHangUp: { [weak callTarget] identifier in
                    callTarget?.softphoneHangUpCall(withIdentifier: identifier)
                },
                onToggleMute: { [weak callTarget] identifier in
                    callTarget?.softphoneToggleMuteForCall(withIdentifier: identifier)
                },
                onSendDTMFDigit: { [weak callTarget] digit, identifier in
                    callTarget?.softphoneSendDTMFDigit(digit, forCallWithIdentifier: identifier)
                }
            )
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}

struct SoftphoneAppShellView: View {
    let accountDisplayName: String
    let sipAddress: String
    @ObservedObject var callHistoryStore: SoftphoneCallHistoryStore
    @ObservedObject var messageStore: SoftphoneMessageStore
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    @ObservedObject var activeCallStore: SoftphoneActiveCallStore
    let onCall: (String) -> Void
    let onPickCallHistoryRecord: (String) -> Void
    let onHangUp: (String) -> Void
    let onToggleMute: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void

    @State private var selectedItem: SoftphoneNavigationItem = .keypad
    @State private var isSidebarCollapsed = false
    @State private var dialPad = SoftphoneDialPad()
    @State private var hadActiveCall = false

    var body: some View {
        HStack(spacing: 0) {
            SoftphoneSidebar(
                selectedItem: $selectedItem,
                isCollapsed: $isSidebarCollapsed
            )
            Divider()
            VStack(spacing: 0) {
                SoftphoneTopStatusBar(
                    selectedItem: selectedItem,
                    registrationState: diagnosticsStore.snapshot.registrationState,
                    accountDisplayName: accountDisplayName,
                    sipAddress: sipAddress
                )
                Divider()
                SoftphoneMainContent(
                    selectedItem: selectedItem,
                    dialPad: $dialPad,
                    callHistoryStore: callHistoryStore,
                    messageStore: messageStore,
                    diagnosticsStore: diagnosticsStore,
                    activeCallStore: activeCallStore,
                    onCall: onCall,
                    onPickCallHistoryRecord: onPickCallHistoryRecord,
                    onHangUp: onHangUp,
                    onToggleMute: onToggleMute,
                    onSendDTMFDigit: onSendDTMFDigit
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, minHeight: 560)
        .background(SoftphoneTheme.windowBackground)
        .onReceive(activeCallStore.$calls) { calls in
            let hasActiveCall = !calls.isEmpty
            if hasActiveCall {
                selectedItem = .keypad
                if !hadActiveCall {
                    dialPad.clear()
                }
            }
            hadActiveCall = hasActiveCall
        }
    }
}

enum SoftphoneNavigationItem: String, CaseIterable, Identifiable {
    case keypad
    case messages
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keypad:
            return "Keypad"
        case .messages:
            return "Messages"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var systemImageName: String {
        switch self {
        case .keypad:
            return "circle.grid.3x3.fill"
        case .messages:
            return "message.fill"
        case .history:
            return "clock.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}

private extension SoftphoneRegistrationState {
    var color: Color {
        switch self {
        case .registered:
            return SoftphoneTheme.green
        case .registering:
            return SoftphoneTheme.amber
        case .failed:
            return SoftphoneTheme.red
        case .offline:
            return SoftphoneTheme.muted
        }
    }
}

private extension CallStatsQuality {
    var title: String {
        switch self {
        case .waiting:
            return "Stats pending"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        @unknown default:
            return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .waiting:
            return SoftphoneTheme.placeholder
        case .good:
            return SoftphoneTheme.green
        case .fair:
            return SoftphoneTheme.amber
        case .poor:
            return SoftphoneTheme.red
        @unknown default:
            return SoftphoneTheme.muted
        }
    }
}

private struct SoftphoneSidebar: View {
    @Binding var selectedItem: SoftphoneNavigationItem
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(alignment: isCollapsed ? .center : .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(width: 34, height: 34)

                if !isCollapsed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SIPMan")
                            .font(.system(size: 13, weight: .semibold))
                        Text("SIP softphone")
                            .font(.system(size: 11))
                            .foregroundStyle(SoftphoneTheme.muted)
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            VStack(spacing: 5) {
                ForEach(SoftphoneNavigationItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImageName)
                                .frame(width: 20, height: 20)
                            if !isCollapsed {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                        .padding(.horizontal, isCollapsed ? 0 : 10)
                        .frame(height: 40)
                        .foregroundStyle(selectedItem == item ? SoftphoneTheme.text : SoftphoneTheme.muted)
                        .background(selectedItem == item ? SoftphoneTheme.selectedControlBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            }

            Spacer()
        }
        .padding(14)
        .frame(width: isCollapsed ? 64 : 196)
        .background(SoftphoneTheme.sidebarBackground)
    }
}

private struct SoftphoneTopStatusBar: View {
    let selectedItem: SoftphoneNavigationItem
    let registrationState: SoftphoneRegistrationState
    let accountDisplayName: String
    let sipAddress: String

    var body: some View {
        HStack(spacing: 10) {
            if selectedItem == .messages {
                SoftphoneSearchFieldPlaceholder(height: 36, cornerRadius: 18, trailingPadding: 0)
                    .frame(width: 300)
            }
            Spacer()
            SoftphonePill {
                Circle()
                    .fill(registrationState.color)
                    .frame(width: 9, height: 9)
                Text(registrationState.title)
            }
            SoftphonePill {
                Text(displayAddress)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
    }

    private var displayAddress: String {
        if !sipAddress.isEmpty {
            return sipAddress
        }
        if !accountDisplayName.isEmpty {
            return accountDisplayName
        }
        return "No account"
    }
}

private struct SoftphonePill<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SoftphoneTheme.muted)
        .padding(.horizontal, 13)
        .frame(height: 36)
        .background(SoftphoneTheme.controlBackground)
        .clipShape(Capsule())
    }
}

private struct SoftphoneMainContent: View {
    let selectedItem: SoftphoneNavigationItem
    @Binding var dialPad: SoftphoneDialPad
    @ObservedObject var callHistoryStore: SoftphoneCallHistoryStore
    @ObservedObject var messageStore: SoftphoneMessageStore
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    @ObservedObject var activeCallStore: SoftphoneActiveCallStore
    let onCall: (String) -> Void
    let onPickCallHistoryRecord: (String) -> Void
    let onHangUp: (String) -> Void
    let onToggleMute: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void

    var body: some View {
        Group {
            switch selectedItem {
            case .keypad:
                SoftphoneKeypadScreen(
                    dialPad: $dialPad,
                    activeCall: activeCallStore.primaryCall,
                    onCall: onCall,
                    onHangUp: onHangUp,
                    onToggleMute: onToggleMute,
                    onSendDTMFDigit: onSendDTMFDigit
                )
            case .messages:
                SoftphoneMessagesScreen(messageStore: messageStore)
            case .history:
                SoftphoneHistoryScreen(callHistoryStore: callHistoryStore, onPickRecord: onPickCallHistoryRecord)
            case .settings:
                SoftphoneSettingsScreen(diagnosticsStore: diagnosticsStore)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SoftphoneActiveCallPanel: View {
    let call: SoftphoneActiveCallModel

    @State private var showsStats = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(SoftphoneTheme.green)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(call.remoteParty)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(1)
                    Text(call.status)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SoftphoneTheme.muted)
                }

                Spacer()

                if !call.duration.isEmpty {
                    SoftphonePill {
                        Image(systemName: "timer")
                        Text(call.duration)
                    }
                }

                SoftphoneQualityPill(quality: call.quality)

                if call.isMuted {
                    SoftphoneStatusIcon(systemName: "mic.slash.fill", help: "Muted")
                }

                if call.isOnHold {
                    SoftphoneStatusIcon(systemName: "pause.fill", help: "On hold")
                }

                if !call.statsRows.isEmpty {
                    Button {
                        showsStats.toggle()
                    } label: {
                        Image(systemName: showsStats ? "chart.bar.xaxis" : "chart.bar")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help(showsStats ? "Hide call stats" : "Show call stats")
                }
            }

            if showsStats {
                SoftphoneCallStatsTable(rows: call.statsRows)
            }
        }
        .padding(14)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SoftphoneStatusIcon: View {
    let systemName: String
    let help: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(SoftphoneTheme.muted)
            .frame(width: 30, height: 30)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(Circle())
            .help(help)
    }
}

private struct SoftphoneQualityPill: View {
    let quality: CallStatsQuality

    var body: some View {
        SoftphonePill {
            Circle()
                .fill(quality.color)
                .frame(width: 8, height: 8)
            Text(quality.title)
        }
    }
}

private struct SoftphoneCallStatsTable: View {
    let rows: [SoftphoneCallStatsRowModel]

    var body: some View {
        VStack(spacing: 0) {
            SoftphoneCallStatsRow(metric: "Metric", live: "Live", peak: "Peak", isHeader: true)
            ForEach(rows) { row in
                Divider()
                SoftphoneCallStatsRow(metric: row.metric, live: row.live, peak: row.peak, isHeader: false)
            }
        }
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SoftphoneCallStatsRow: View {
    let metric: String
    let live: String
    let peak: String
    let isHeader: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(metric)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(live)
                .frame(width: 150, alignment: .leading)
            Text(peak)
                .frame(width: 150, alignment: .leading)
        }
        .font(.system(size: 12, weight: isHeader ? .bold : .regular, design: .monospaced))
        .foregroundStyle(isHeader ? SoftphoneTheme.text : SoftphoneTheme.muted)
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(.horizontal, 12)
        .frame(height: 30)
    }
}

private struct SoftphoneKeypadScreen: View {
    @Binding var dialPad: SoftphoneDialPad
    let activeCall: SoftphoneActiveCallModel?
    let onCall: (String) -> Void
    let onHangUp: (String) -> Void
    let onToggleMute: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void

    private let keys = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"),
        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
        ("*", ""), ("0", "+"), ("#", "")
    ]

    var body: some View {
        VStack(spacing: verticalSpacing) {
            if let activeCall {
                SoftphoneInlineCallHeader(call: activeCall)
            }

            if activeCall == nil {
                keypadDisplay
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(keyWidth), spacing: keySpacing), count: 3), spacing: keySpacing) {
                ForEach(keys, id: \.0) { key in
                    Button {
                        appendKeypadValue(key.0)
                    } label: {
                        VStack(spacing: keyLabelSpacing) {
                            Text(key.0)
                                .font(.system(size: keyDigitFontSize, weight: .medium))
                            Text(key.1)
                                .font(.system(size: keyLetterFontSize, weight: .bold))
                                .foregroundStyle(SoftphoneTheme.placeholder)
                                .frame(height: keyLetterHeight)
                        }
                        .frame(width: keyWidth, height: keyHeight)
                        .background(SoftphoneTheme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            callControls
        }
        .frame(maxWidth: 390)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            SoftphoneKeyboardCaptureView { action in
                handleKeyboardAction(action)
            }
            .frame(width: 0, height: 0)
        )
    }

    private var isInCall: Bool {
        activeCall != nil
    }

    private var verticalSpacing: CGFloat {
        isInCall ? 10 : 18
    }

    private var keyWidth: CGFloat {
        118
    }

    private var keyHeight: CGFloat {
        isInCall ? 56 : 66
    }

    private var keySpacing: CGFloat {
        isInCall ? 10 : 13
    }

    private var keyLabelSpacing: CGFloat {
        isInCall ? 2 : 6
    }

    private var keyDigitFontSize: CGFloat {
        isInCall ? 24 : 27
    }

    private var keyLetterFontSize: CGFloat {
        isInCall ? 9 : 10
    }

    private var keyLetterHeight: CGFloat {
        isInCall ? 8 : 10
    }

    private var keyCornerRadius: CGFloat {
        isInCall ? 18 : 22
    }

    private var keypadDisplay: some View {
        Text(displayText)
            .font(.system(size: displayFontSize, weight: .semibold))
            .foregroundStyle(displayText == placeholderText ? SoftphoneTheme.placeholder : SoftphoneTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: isInCall ? 42 : 64)
            .padding(.horizontal, isInCall ? 14 : 18)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: isInCall ? 16 : 20, style: .continuous))
    }

    private var displayFontSize: CGFloat {
        if displayText == placeholderText {
            return isInCall ? 17 : 22
        }
        return isInCall ? 23 : 30
    }

    @ViewBuilder
    private var callControls: some View {
        if let activeCall {
            HStack(spacing: 12) {
                Button {
                    onToggleMute(activeCall.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: activeCall.isMuted ? "mic.slash.fill" : "mic.fill")
                        Text(activeCall.isMuted ? "Unmute" : "Mute")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle())

                Button {
                    onHangUp(activeCall.id)
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 118, height: 48)
                        .background(SoftphoneTheme.red)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Hang up")
            }
        } else {
            HStack(spacing: 12) {
                Button("Clear") {
                    dialPad.clear()
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle())

                Button {
                    guard dialPad.canCall else { return }
                    onCall(dialPad.destination)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 82, height: 56)
                        .background(dialPad.canCall ? SoftphoneTheme.green : SoftphoneTheme.placeholder)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!dialPad.canCall)

                Button("Delete") {
                    dialPad.deleteLast()
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle())
            }
        }
    }

    private var placeholderText: String {
        activeCall == nil ? "Enter number" : "DTMF"
    }

    private var displayText: String {
        dialPad.destination.isEmpty ? placeholderText : dialPad.destination
    }

    private func handleKeyboardAction(_ action: SoftphoneKeypadKeyboardAction) {
        switch action {
        case .append(let value):
            appendKeypadValue(value)
        case .deleteLast:
            dialPad.deleteLast()
        case .clear:
            dialPad.clear()
        case .submit:
            guard activeCall == nil, dialPad.canCall else { return }
            onCall(dialPad.destination)
        }
    }

    private func appendKeypadValue(_ value: String) {
        if let activeCall {
            guard value.count == 1, let character = value.first, "0123456789*#".contains(character) else {
                return
            }
            onSendDTMFDigit(value, activeCall.id)
        } else {
            dialPad.append(value)
        }
    }
}

private struct SoftphoneKeyboardCaptureView: NSViewRepresentable {
    let onAction: (SoftphoneKeypadKeyboardAction) -> Void

    func makeNSView(context: Context) -> SoftphoneKeyboardCaptureNSView {
        let view = SoftphoneKeyboardCaptureNSView()
        view.onAction = onAction
        return view
    }

    func updateNSView(_ nsView: SoftphoneKeyboardCaptureNSView, context: Context) {
        nsView.onAction = onAction
        nsView.requestFocus()
    }
}

private final class SoftphoneKeyboardCaptureNSView: NSView {
    var onAction: ((SoftphoneKeypadKeyboardAction) -> Void)?
    private var eventMonitor: Any?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateEventMonitor()
        requestFocus()
    }

    deinit {
        MainActor.assumeIsolated {
            removeEventMonitor()
        }
    }

    func requestFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.firstResponder !== self {
                window.makeFirstResponder(self)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard handle(event) else {
            super.keyDown(with: event)
            return
        }
    }

    private func updateEventMonitor() {
        removeEventMonitor()
        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(blockedModifiers).isEmpty,
              let action = SoftphoneKeypadKeyboardAction(characters: event.characters, keyCode: event.keyCode) else {
            return false
        }

        onAction?(action)
        return true
    }
}

private struct SoftphoneInlineCallHeader: View {
    let call: SoftphoneActiveCallModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(SoftphoneTheme.green)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(call.remoteParty)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(SoftphoneTheme.text)
                    .lineLimit(1)
                Text(call.status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoftphoneTheme.muted)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "timer")
                Text(call.duration.isEmpty ? "00:00" : call.duration)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(SoftphoneTheme.muted)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SoftphoneMessagesScreen: View {
    @ObservedObject var messageStore: SoftphoneMessageStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if messageStore.conversations.isEmpty {
                    SoftphoneEmptyState(title: "No messages", subtitle: "SIP MESSAGE conversations will appear here.")
                } else {
                    ForEach(messageStore.conversations) { conversation in
                        SoftphoneConversationRow(
                            conversation: conversation,
                            isSelected: conversation.id == messageStore.selectedConversationId
                        ) {
                            messageStore.selectConversation(id: conversation.id)
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 300)
            Divider()
            VStack(spacing: 0) {
                if let selectedConversation = messageStore.conversations.first(where: { $0.id == messageStore.selectedConversationId }) {
                    SoftphoneMessageHeader(conversation: selectedConversation)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messageStore.messages) { message in
                                SoftphoneMessageBubble(message: message)
                            }
                        }
                        .padding(18)
                    }
                    SoftphoneMessageComposerPlaceholder()
                } else {
                    SoftphoneEmptyState(title: "Select a conversation", subtitle: "SIP MESSAGE details will appear here.")
                }
            }
        }
    }
}

private struct SoftphoneHistoryScreen: View {
    @ObservedObject var callHistoryStore: SoftphoneCallHistoryStore
    let onPickRecord: (String) -> Void

    @State private var selectedFilter: SoftphoneCallHistoryFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 21, weight: .bold))
                    Text("Inbound and outbound SIP call history.")
                        .font(.system(size: 13))
                        .foregroundStyle(SoftphoneTheme.muted)
                }
                Spacer()
                SoftphoneHistoryFilterControl(selectedFilter: $selectedFilter)
            }
            Divider()
            if filteredRows.isEmpty {
                SoftphoneEmptyState(title: emptyStateTitle, subtitle: emptyStateSubtitle)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredRows) { row in
                            SoftphoneCallHistoryRow(row: row) {
                                onPickRecord(row.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            Spacer()
        }
    }

    private var filteredRows: [SoftphoneCallHistoryRowModel] {
        callHistoryStore.rows(matching: selectedFilter)
    }

    private var emptyStateTitle: String {
        selectedFilter == .all ? "No recent calls" : "No \(selectedFilter.title.lowercased()) calls"
    }

    private var emptyStateSubtitle: String {
        selectedFilter == .all ? "Completed and missed calls will appear here." : "Calls matching this filter will appear here."
    }
}

private enum SoftphoneSettingsTab: String, CaseIterable, Identifiable {
    case account
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account:
            return "Account"
        case .diagnostics:
            return "Diagnostics"
        }
    }
}

private struct SoftphoneSettingsScreen: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore

    @State private var selectedTab: SoftphoneSettingsTab = .account

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SoftphoneSettingsTabControl(selectedTab: $selectedTab)

            switch selectedTab {
            case .account:
                SoftphoneAccountSettingsPane(diagnosticsStore: diagnosticsStore)
            case .diagnostics:
                SoftphoneDiagnosticsSettingsPane(diagnosticsStore: diagnosticsStore)
            }

            Spacer()
        }
    }
}

private struct SoftphoneSettingsTabControl: View {
    @Binding var selectedTab: SoftphoneSettingsTab

    var body: some View {
        HStack(spacing: 3) {
            ForEach(SoftphoneSettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .softphoneSegment(isSelected: selectedTab == tab)
                }
                .buttonStyle(.plain)
                .help("Show \(tab.title.lowercased()) settings")
            }
        }
        .padding(4)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(Capsule())
    }
}

private struct SoftphoneAccountSettingsPane: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoftphoneSectionHeader(title: "Account", subtitle: "SIP account configuration.")
            HStack(spacing: 12) {
                SoftphoneLabeledField(label: "SIP address", value: diagnosticsStore.snapshot.sipAddress)
                SoftphoneLabeledField(label: "Domain", value: diagnosticsStore.snapshot.domain)
            }
            SoftphoneLabeledField(label: "Account UUID", value: diagnosticsStore.snapshot.accountUUID)
            HStack(spacing: 12) {
                SoftphoneLabeledField(label: "Transport", value: diagnosticsStore.snapshot.transport)
                SoftphoneLabeledField(label: "Port", value: diagnosticsStore.snapshot.port)
            }
        }
    }
}

private struct SoftphoneDiagnosticsSettingsPane: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SoftphoneSectionHeader(title: "Diagnostics", subtitle: "Registration and SIP troubleshooting.")
            HStack(spacing: 8) {
                SoftphoneDiagnosticTile(label: "Registration", value: diagnosticsStore.snapshot.registrationState.title)
                SoftphoneDiagnosticTile(label: "Last registered", value: diagnosticsStore.snapshot.lastRegistration)
                SoftphoneDiagnosticTile(
                    label: "Transport",
                    value: "\(diagnosticsStore.snapshot.transport) - \(diagnosticsStore.snapshot.port)"
                )
            }
            SoftphoneLogPlaceholder()
        }
    }
}

private struct SoftphoneSearchFieldPlaceholder: View {
    var height: CGFloat = 42
    var cornerRadius: CGFloat = 14
    var trailingPadding: CGFloat = 14

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            Text("Search")
            Spacer()
        }
        .foregroundStyle(SoftphoneTheme.placeholder)
        .padding(.horizontal, 14)
        .frame(height: height)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .padding(.trailing, trailingPadding)
    }
}

private struct SoftphoneConversationRow: View {
    let conversation: SoftphoneMessageConversationRowModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 11) {
                SoftphoneAvatar(initials: initials(for: conversation.title))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(conversation.title)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(conversation.date)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SoftphoneTheme.placeholder)
                    }
                    Text(conversation.preview)
                        .font(.system(size: 12))
                        .foregroundStyle(SoftphoneTheme.muted)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(isSelected ? SoftphoneTheme.selectedControlBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.trailing, 14)
        }
        .buttonStyle(.plain)
    }

    private func initials(for value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        let result = parts.compactMap(\.first).map(String.init).joined()
        return result.isEmpty ? "#" : result.uppercased()
    }
}

private struct SoftphoneMessageHeader: View {
    let conversation: SoftphoneMessageConversationRowModel

    var body: some View {
        HStack {
            SoftphoneAvatar(initials: "#")
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.system(size: 15, weight: .semibold))
                Text(conversation.id)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(SoftphoneTheme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 72)
    }
}

private struct SoftphoneMessageBubble: View {
    let message: SoftphoneMessageBubbleModel

    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 52)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.body)
                    .font(.system(size: 13))
                Text("\(message.date) - \(message.deliveryState)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(message.isOutgoing ? .white.opacity(0.72) : SoftphoneTheme.muted)
            }
            .padding(12)
            .background(message.isOutgoing ? SoftphoneTheme.blue : SoftphoneTheme.fieldBackground)
            .foregroundStyle(message.isOutgoing ? .white : SoftphoneTheme.text)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !message.isOutgoing {
                Spacer(minLength: 52)
            }
        }
    }
}

private struct SoftphoneMessageComposerPlaceholder: View {
    var body: some View {
        HStack {
            Text("Message")
                .foregroundStyle(SoftphoneTheme.placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .frame(height: 46)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button {
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(SoftphonePrimaryIconButtonStyle())
            .disabled(true)
        }
        .padding(14)
    }
}

private struct SoftphoneAvatar: View {
    let initials: String

    var body: some View {
        Text(initials)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct SoftphoneHistoryFilterControl: View {
    @Binding var selectedFilter: SoftphoneCallHistoryFilter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(SoftphoneCallHistoryFilter.allCases) { filter in
                Button {
                    selectedFilter = filter
                } label: {
                    Text(filter.title)
                        .softphoneSegment(isSelected: selectedFilter == filter)
                }
                .buttonStyle(.plain)
                .help("Show \(filter.title.lowercased()) calls")
            }
        }
        .padding(4)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(Capsule())
    }
}

private struct SoftphoneCallHistoryRow: View {
    let row: SoftphoneCallHistoryRowModel
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbolName)
                .foregroundStyle(row.isMissed ? SoftphoneTheme.red : SoftphoneTheme.blue)
                .frame(width: 42, height: 42)
                .background((row.isMissed ? SoftphoneTheme.red : SoftphoneTheme.blue).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(row.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(SoftphoneTheme.muted)
            }
            Spacer()
            Button {
                onCall()
            } label: {
                Image(systemName: "phone.fill")
            }
            .buttonStyle(SoftphonePrimaryIconButtonStyle(color: SoftphoneTheme.green))
        }
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SoftphoneEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(SoftphoneTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
    }
}

private struct SoftphoneSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 21, weight: .bold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(SoftphoneTheme.muted)
        }
    }
}

private struct SoftphoneLabeledField: View {
    let label: String
    let value: String
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SoftphoneTheme.muted)
            Text(isSecure && !value.isEmpty ? String(repeating: "*", count: value.count) : value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }
}

private struct SoftphoneDiagnosticTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(SoftphoneTheme.muted)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct SoftphoneLogPlaceholder: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Rolling SIP log")
                Spacer()
                Text("Last 250 lines")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.72))
            .padding(12)
            Divider().background(.white.opacity(0.1))
            Text("SIP log will appear here once diagnostics are connected.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)
        }
        .frame(minHeight: 240)
        .background(Color(red: 0.08, green: 0.1, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SoftphoneSecondaryButtonStyle: ButtonStyle {
    var width: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(SoftphoneTheme.muted)
            .frame(width: width, height: 48)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct SoftphonePrimaryIconButtonStyle: ButtonStyle {
    var color: Color = SoftphoneTheme.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension View {
    func softphoneSegment(isSelected: Bool) -> some View {
        self
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isSelected ? SoftphoneTheme.text : SoftphoneTheme.muted)
            .padding(.horizontal, 11)
            .frame(height: 29)
            .background(isSelected ? Color.white.opacity(0.9) : Color.clear)
            .clipShape(Capsule())
    }
}

private enum SoftphoneTheme {
    static let text = Color(red: 0.08, green: 0.1, blue: 0.14)
    static let muted = Color(red: 0.43, green: 0.46, blue: 0.5)
    static let placeholder = Color(red: 0.6, green: 0.64, blue: 0.68)
    static let blue = Color(red: 0.04, green: 0.52, blue: 1)
    static let green = Color(red: 0.19, green: 0.82, blue: 0.35)
    static let red = Color(red: 1, green: 0.27, blue: 0.23)
    static let amber = Color(red: 1, green: 0.62, blue: 0.04)
    static let windowBackground = Color(red: 0.94, green: 0.96, blue: 0.98)
    static let sidebarBackground = Color.white.opacity(0.54)
    static let controlBackground = Color.white.opacity(0.78)
    static let selectedControlBackground = Color.white.opacity(0.92)
    static let fieldBackground = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let rowBackground = Color.white.opacity(0.56)
}
