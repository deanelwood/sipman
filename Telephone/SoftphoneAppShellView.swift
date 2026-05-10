//
//  SoftphoneAppShellView.swift
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2026 64 Characters
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

@objc
@MainActor
protocol SoftphoneCallTarget: AnyObject {
    @objc(softphoneMakeCallTo:)
    func softphoneMakeCall(to destination: String)
    @objc(softphonePickCallHistoryRecordWithIdentifier:)
    func softphonePickCallHistoryRecord(withIdentifier identifier: String)
}

@objcMembers
final class SoftphoneAppShellViewFactory: NSObject {
    @MainActor
    @objc(makeViewWithCallTarget:accountDisplayName:sipAddress:callHistoryStore:messageStore:)
    static func makeView(
        callTarget: SoftphoneCallTarget,
        accountDisplayName: String,
        sipAddress: String,
        callHistoryStore: SoftphoneCallHistoryStore,
        messageStore: SoftphoneMessageStore
    ) -> NSView {
        let view = NSHostingView(
            rootView: SoftphoneAppShellView(
                accountDisplayName: accountDisplayName,
                sipAddress: sipAddress,
                callHistoryStore: callHistoryStore,
                messageStore: messageStore,
                onCall: { [weak callTarget] destination in
                    callTarget?.softphoneMakeCall(to: destination)
                },
                onPickCallHistoryRecord: { [weak callTarget] identifier in
                    callTarget?.softphonePickCallHistoryRecord(withIdentifier: identifier)
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
    let onCall: (String) -> Void
    let onPickCallHistoryRecord: (String) -> Void

    @State private var selectedItem: SoftphoneNavigationItem = .keypad
    @State private var isSidebarCollapsed = false
    @State private var dialPad = SoftphoneDialPad()

    var body: some View {
        HStack(spacing: 0) {
            SoftphoneSidebar(
                selectedItem: $selectedItem,
                isCollapsed: $isSidebarCollapsed
            )
            Divider()
            VStack(spacing: 0) {
                SoftphoneTopStatusBar(
                    registrationState: .offline,
                    accountDisplayName: accountDisplayName,
                    sipAddress: sipAddress
                )
                Divider()
                SoftphoneMainContent(
                    selectedItem: selectedItem,
                    dialPad: $dialPad,
                    callHistoryStore: callHistoryStore,
                    messageStore: messageStore,
                    onCall: onCall,
                    onPickCallHistoryRecord: onPickCallHistoryRecord
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 840, minHeight: 560)
        .background(SoftphoneTheme.windowBackground)
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

enum SoftphoneRegistrationState {
    case registered
    case registering
    case failed
    case offline

    var title: String {
        switch self {
        case .registered:
            return "Registered"
        case .registering:
            return "Registering"
        case .failed:
            return "Registration failed"
        case .offline:
            return "Offline"
        }
    }

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

private struct SoftphoneSidebar: View {
    @Binding var selectedItem: SoftphoneNavigationItem
    @Binding var isCollapsed: Bool

    var body: some View {
        VStack(alignment: isCollapsed ? .center : .leading, spacing: 18) {
            HStack {
                SoftphoneWindowDots()
                Spacer(minLength: 0)
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: isCollapsed ? "sidebar.right" : "sidebar.left")
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .background(SoftphoneTheme.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("T")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 36, height: 36)

                if !isCollapsed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Telephone")
                            .font(.system(size: 14, weight: .semibold))
                        Text("SIP softphone")
                            .font(.system(size: 12))
                            .foregroundStyle(SoftphoneTheme.muted)
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            VStack(spacing: 6) {
                ForEach(SoftphoneNavigationItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.systemImageName)
                                .frame(width: 22, height: 22)
                            if !isCollapsed {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
                        .padding(.horizontal, isCollapsed ? 0 : 12)
                        .frame(height: 44)
                        .foregroundStyle(selectedItem == item ? SoftphoneTheme.text : SoftphoneTheme.muted)
                        .background(selectedItem == item ? SoftphoneTheme.selectedControlBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            }

            Spacer()
        }
        .padding(18)
        .frame(width: isCollapsed ? 76 : 236)
        .background(SoftphoneTheme.sidebarBackground)
    }
}

private struct SoftphoneWindowDots: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
            Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
            Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
        }
        .frame(width: 52, height: 12)
    }
}

private struct SoftphoneTopStatusBar: View {
    let registrationState: SoftphoneRegistrationState
    let accountDisplayName: String
    let sipAddress: String

    var body: some View {
        HStack(spacing: 10) {
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
    let onCall: (String) -> Void
    let onPickCallHistoryRecord: (String) -> Void

    var body: some View {
        Group {
            switch selectedItem {
            case .keypad:
                SoftphoneKeypadScreen(dialPad: $dialPad, onCall: onCall)
            case .messages:
                SoftphoneMessagesScreen(messageStore: messageStore)
            case .history:
                SoftphoneHistoryScreen(callHistoryStore: callHistoryStore, onPickRecord: onPickCallHistoryRecord)
            case .settings:
                SoftphoneSettingsPlaceholder()
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SoftphoneKeypadScreen: View {
    @Binding var dialPad: SoftphoneDialPad
    let onCall: (String) -> Void

    private let keys = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"),
        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
        ("*", ""), ("0", "+"), ("#", "")
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text(dialPad.destination.isEmpty ? "Enter number" : dialPad.destination)
                .font(.system(size: dialPad.destination.isEmpty ? 22 : 30, weight: .semibold))
                .foregroundStyle(dialPad.destination.isEmpty ? SoftphoneTheme.placeholder : SoftphoneTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .padding(.horizontal, 18)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(118), spacing: 13), count: 3), spacing: 13) {
                ForEach(keys, id: \.0) { key in
                    Button {
                        dialPad.append(key.0)
                    } label: {
                        VStack(spacing: 6) {
                            Text(key.0)
                                .font(.system(size: 27, weight: .medium))
                            Text(key.1)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(SoftphoneTheme.placeholder)
                                .frame(height: 10)
                        }
                        .frame(width: 118, height: 66)
                        .background(SoftphoneTheme.controlBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

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
        .frame(maxWidth: 390)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SoftphoneMessagesScreen: View {
    @ObservedObject var messageStore: SoftphoneMessageStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                SoftphoneSearchFieldPlaceholder()
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
                SoftphoneSegmentedPlaceholder()
            }
            Divider()
            if callHistoryStore.rows.isEmpty {
                SoftphoneEmptyState(title: "No recent calls", subtitle: "Completed and missed calls will appear here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(callHistoryStore.rows) { row in
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
}

private struct SoftphoneSettingsPlaceholder: View {
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                SoftphoneSectionHeader(title: "Account", subtitle: "SIP account configuration.")
                SoftphoneLabeledField(label: "Username", value: "")
                SoftphoneLabeledField(label: "Password", value: "", isSecure: true)
                SoftphoneLabeledField(label: "Domain", value: "")
                HStack {
                    SoftphoneLabeledField(label: "Transport", value: "UDP")
                    SoftphoneLabeledField(label: "Port", value: "5060")
                }
                Spacer()
            }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                SoftphoneSectionHeader(title: "Diagnostics", subtitle: "Registration and SIP troubleshooting.")
                HStack(spacing: 8) {
                    SoftphoneDiagnosticTile(label: "Registration", value: "Offline")
                    SoftphoneDiagnosticTile(label: "Last registered", value: "--")
                    SoftphoneDiagnosticTile(label: "Transport", value: "UDP - 5060")
                }
                SoftphoneLogPlaceholder()
                Spacer()
            }
        }
    }
}

private struct SoftphoneSearchFieldPlaceholder: View {
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            Text("Search")
            Spacer()
        }
        .foregroundStyle(SoftphoneTheme.placeholder)
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.trailing, 14)
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

private struct SoftphoneSegmentedPlaceholder: View {
    var body: some View {
        HStack(spacing: 3) {
            Text("All").softphoneSegment(isSelected: true)
            Text("Inbound").softphoneSegment(isSelected: false)
            Text("Outbound").softphoneSegment(isSelected: false)
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
