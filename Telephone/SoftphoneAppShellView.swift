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
import Contacts
import SwiftUI
import UniformTypeIdentifiers
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
    @objc(softphoneToggleHoldForCallWithIdentifier:)
    func softphoneToggleHoldForCall(withIdentifier identifier: String)
    @objc(softphoneSendDTMFDigit:forCallWithIdentifier:)
    func softphoneSendDTMFDigit(_ digit: String, forCallWithIdentifier identifier: String)
    @objc(softphoneSendSIPOptionsPingTo:transport:completion:)
    func softphoneSendSIPOptionsPing(
        to destination: String,
        transport: String,
        completion: @escaping ([String: Any]) -> Void
    )
    @objc(softphoneSaveNetworkSettings:)
    func softphoneSaveNetworkSettings(_ settings: [String: Any])
    @objc(softphoneSaveAccountSettings:)
    func softphoneSaveAccountSettings(_ settings: [String: Any])
    @objc(softphoneLogOutAccount)
    func softphoneLogOutAccount()
}

private enum SoftphoneAccountSettingsKey {
    static let password = "Password"
}

private enum SoftphoneAccountTransport: String, CaseIterable, Identifiable {
    case udp = "UDP"
    case tcp = "TCP"
    case tls = "TLS"

    var id: String { rawValue }
    var title: String { rawValue }
    var defaultPort: String { self == .tls ? "5061" : "5060" }

    init(displayValue: String) {
        switch displayValue.trimmed.uppercased() {
        case Self.tcp.rawValue:
            self = .tcp
        case Self.tls.rawValue:
            self = .tls
        default:
            self = .udp
        }
    }
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
                onToggleHold: { [weak callTarget] identifier in
                    callTarget?.softphoneToggleHoldForCall(withIdentifier: identifier)
                },
                onSendDTMFDigit: { [weak callTarget] digit, identifier in
                    callTarget?.softphoneSendDTMFDigit(digit, forCallWithIdentifier: identifier)
                },
                onSIPPing: { [weak callTarget] destination, transport, completion in
                    callTarget?.softphoneSendSIPOptionsPing(to: destination, transport: transport, completion: completion)
                },
                onSaveNetworkSettings: { [weak callTarget] settings in
                    callTarget?.softphoneSaveNetworkSettings(settings)
                },
                onSaveAccountSettings: { [weak callTarget] settings in
                    callTarget?.softphoneSaveAccountSettings(settings)
                },
                onLogOut: { [weak callTarget] in
                    callTarget?.softphoneLogOutAccount()
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
    let onToggleHold: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void
    let onSIPPing: (String, String, @escaping ([String: Any]) -> Void) -> Void
    let onSaveNetworkSettings: ([String: Any]) -> Void
    let onSaveAccountSettings: ([String: Any]) -> Void
    let onLogOut: () -> Void

    @AppStorage(SoftphoneAppearance.userDefaultsKey) private var appearanceModeRawValue = SoftphoneAppearanceMode.light.rawValue
    @State private var selectedItem: SoftphoneNavigationItem = .keypad
    @State private var dialPad = SoftphoneDialPad()
    @State private var hadActiveCall = false

    var body: some View {
        HStack(spacing: 0) {
            SoftphoneSidebar(selectedItem: $selectedItem)
            Divider()
            VStack(spacing: 0) {
                SoftphoneTopStatusBar(
                    selectedItem: selectedItem,
                    registrationState: diagnosticsStore.snapshot.registrationState,
                    accountDisplayName: diagnosticsStore.snapshot.username.isEmpty ? accountDisplayName : diagnosticsStore.snapshot.username,
                    sipAddress: diagnosticsStore.snapshot.sipAddress.isEmpty ? sipAddress : diagnosticsStore.snapshot.sipAddress
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
                    onToggleHold: onToggleHold,
                    onSendDTMFDigit: onSendDTMFDigit,
                    onSIPPing: onSIPPing,
                    onSaveNetworkSettings: onSaveNetworkSettings,
                    onSaveAccountSettings: onSaveAccountSettings,
                    onLogOut: onLogOut
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 840, minHeight: 560)
        .foregroundStyle(SoftphoneTheme.text)
        .background(SoftphoneTheme.windowBackground)
        .background(SoftphoneWindowAppearanceBinder(mode: appearanceMode).frame(width: 0, height: 0))
        .preferredColorScheme(appearanceMode.colorScheme)
        .onReceive(activeCallStore.$calls) { calls in
            let hasActiveCall = !calls.isEmpty
            if hasActiveCall && !hadActiveCall {
                selectedItem = .keypad
                dialPad.clear()
            }
            hadActiveCall = hasActiveCall
        }
    }

    private var appearanceMode: SoftphoneAppearanceMode {
        SoftphoneAppearanceMode(rawValue: appearanceModeRawValue) ?? .light
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
            return "Calling"
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
            return "phone"
        case .messages:
            return "bubble.left"
        case .history:
            return "clock"
        case .settings:
            return "gearshape"
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

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            VStack(spacing: 3) {
                ForEach(SoftphoneNavigationItem.allCases) { item in
                    Button {
                        selectedItem = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.systemImageName)
                                .font(.system(size: 15, weight: .regular))
                                .frame(width: 18, height: 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 36)
                        .foregroundStyle(selectedItem == item ? SoftphoneTheme.text : SoftphoneTheme.muted)
                        .background(selectedItem == item ? SoftphoneTheme.selectedControlBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(item.title)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 44)
        .padding(.bottom, 16)
        .frame(width: 64)
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
            Text(selectedItem.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SoftphoneTheme.text)
            Spacer()
            SoftphonePill {
                Circle()
                    .fill(registrationState.color)
                    .frame(width: 7, height: 7)
                Text(registrationState.title)
            }
            SoftphonePill {
                Text(displayAddress)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44, alignment: .center)
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
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(SoftphoneTheme.muted)
        .padding(.horizontal, 12)
        .frame(height: 32)
        .fixedSize(horizontal: true, vertical: false)
        .background(SoftphoneTheme.controlBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneMainContent: View {
    let selectedItem: SoftphoneNavigationItem
    @Binding var dialPad: SoftphoneDialPad
    @ObservedObject var callHistoryStore: SoftphoneCallHistoryStore
    @ObservedObject var messageStore: SoftphoneMessageStore
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    @ObservedObject var activeCallStore: SoftphoneActiveCallStore
    @StateObject private var contactBrowserStore = SoftphoneContactBrowserStore()
    let onCall: (String) -> Void
    let onPickCallHistoryRecord: (String) -> Void
    let onHangUp: (String) -> Void
    let onToggleMute: (String) -> Void
    let onToggleHold: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void
    let onSIPPing: (String, String, @escaping ([String: Any]) -> Void) -> Void
    let onSaveNetworkSettings: ([String: Any]) -> Void
    let onSaveAccountSettings: ([String: Any]) -> Void
    let onLogOut: () -> Void

    var body: some View {
        Group {
            switch selectedItem {
            case .keypad:
                SoftphoneCallingScreen(
                    dialPad: $dialPad,
                    activeCall: activeCallStore.primaryCall,
                    contactStore: contactBrowserStore,
                    onCall: onCall,
                    onHangUp: onHangUp,
                    onToggleMute: onToggleMute,
                    onToggleHold: onToggleHold,
                    onSendDTMFDigit: onSendDTMFDigit
                )
            case .messages:
                SoftphoneMessagesScreen(messageStore: messageStore)
            case .history:
                SoftphoneHistoryScreen(
                    callHistoryStore: callHistoryStore,
                    diagnosticsStore: diagnosticsStore,
                    onPickRecord: onPickCallHistoryRecord
                )
            case .settings:
                SoftphoneSettingsScreen(
                    diagnosticsStore: diagnosticsStore,
                    onSIPPing: onSIPPing,
                    onSaveNetworkSettings: onSaveNetworkSettings,
                    onSaveAccountSettings: onSaveAccountSettings,
                    onLogOut: onLogOut
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(selectedItem == .history || selectedItem == .messages ? 0 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum SoftphoneCallingTab: String, CaseIterable, Identifiable {
    case keypad
    case contacts
    case favourites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keypad:
            return "Keypad"
        case .contacts:
            return "Contacts"
        case .favourites:
            return "Favourites"
        }
    }

    var systemImage: String {
        switch self {
        case .keypad:
            return "circle.grid.3x3"
        case .contacts:
            return "person.crop.circle"
        case .favourites:
            return "star"
        }
    }
}

private enum SoftphoneContactAccessState: Equatable {
    case idle
    case requesting
    case authorized
    case denied
    case failed(String)
}

@MainActor
private final class SoftphoneContactBrowserStore: ObservableObject {
    @Published private(set) var accessState: SoftphoneContactAccessState = .idle
    @Published private(set) var model = SoftphoneCallingContactsModel(contacts: [])
    @Published private(set) var loadedContactCount = 0
    @Published private(set) var loadedPhoneNumberCount = 0
    @Published private(set) var hasLoadedContacts = false
    @Published private(set) var isSyncingContacts = false

    private let store = CNContactStore()
    private var syncTask: Task<Void, Never>?

    deinit {
        syncTask?.cancel()
    }

    func refreshIfAuthorized(force: Bool = false) {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            accessState = .authorized
            if force || !hasLoadedContacts {
                loadContacts()
            }
        case .denied, .restricted:
            accessState = .denied
        case .notDetermined:
            accessState = .idle
        @unknown default:
            accessState = .failed("Contacts are not available on this Mac.")
        }
    }

    func requestAccess() {
        accessState = .requesting
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }
                if granted {
                    self.accessState = .authorized
                    self.hasLoadedContacts = false
                    self.loadContacts()
                } else if let error {
                    self.accessState = .failed(error.localizedDescription)
                } else {
                    self.accessState = .denied
                }
            }
        }
    }

    private func loadContacts() {
        guard !isSyncingContacts else { return }

        isSyncingContacts = true
        syncTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                do {
                    return SoftphoneContactSyncResult.success(try SoftphoneContactBrowserStore.fetchContacts())
                } catch {
                    return .failure(error.localizedDescription)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isSyncingContacts = false
            switch result {
            case .success(let fetchedContacts):
                self.loadedContactCount = fetchedContacts.loadedContactCount
                self.loadedPhoneNumberCount = fetchedContacts.loadedPhoneNumberCount
                self.model = SoftphoneCallingContactsModel(contacts: fetchedContacts.contacts.map(\.contact))
                self.hasLoadedContacts = true
                self.accessState = .authorized
            case .failure(let message):
                self.loadedContactCount = 0
                self.loadedPhoneNumberCount = 0
                self.hasLoadedContacts = false
                self.accessState = .failed(message)
            }
        }
    }

    private nonisolated static func fetchContacts() throws -> SoftphoneFetchedContacts {
        let store = CNContactStore()
        var contacts: [SoftphoneContactSnapshot] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch())
        request.sortOrder = .userDefault
        try store.enumerateContacts(with: request) { contact, _ in
            contacts.append(SoftphoneContactSnapshot(contact))
        }
        return SoftphoneFetchedContacts(contacts: contacts)
    }

    private nonisolated static func keysToFetch() -> [CNKeyDescriptor] {
        [
            CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
    }
}

private enum SoftphoneContactSyncResult: Sendable {
    case success(SoftphoneFetchedContacts)
    case failure(String)
}

private struct SoftphoneFetchedContacts: Sendable {
    let contacts: [SoftphoneContactSnapshot]
    let loadedContactCount: Int
    let loadedPhoneNumberCount: Int

    init(contacts: [SoftphoneContactSnapshot]) {
        self.contacts = contacts
        loadedContactCount = contacts.count
        loadedPhoneNumberCount = contacts.reduce(0) { $0 + $1.phones.count }
    }
}

private struct SoftphoneContactSnapshot: Sendable {
    let name: String
    let phones: [Phone]
    let emails: [Email]

    init(_ contact: CNContact) {
        name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        phones = contact.phoneNumbers.map(Phone.init)
        emails = contact.emailAddresses.map(Email.init)
    }

    var contact: Contact {
        Contact(
            name: name,
            phones: phones.map(\.contactPhone),
            emails: emails.map(\.contactEmail)
        )
    }

    struct Phone: Sendable {
        let number: String
        let label: String

        init(_ phone: CNLabeledValue<CNPhoneNumber>) {
            number = phone.value.stringValue
            label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
        }

        var contactPhone: Contact.Phone {
            Contact.Phone(number: number, label: label)
        }
    }

    struct Email: Sendable {
        let address: String
        let label: String

        init(_ email: CNLabeledValue<NSString>) {
            address = email.value as String
            label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
        }

        var contactEmail: Contact.Email {
            Contact.Email(address: address, label: label)
        }
    }
}

private struct SoftphoneCallingScreen: View {
    @Binding var dialPad: SoftphoneDialPad
    let activeCall: SoftphoneActiveCallModel?
    @ObservedObject var contactStore: SoftphoneContactBrowserStore
    let onCall: (String) -> Void
    let onHangUp: (String) -> Void
    let onToggleMute: (String) -> Void
    let onToggleHold: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void

    @State private var selectedTab: SoftphoneCallingTab = .keypad
    @AppStorage(SoftphoneContactFavourites.storageKey) private var favouriteContactIDsRawValue = SoftphoneContactFavourites().rawValue

    var body: some View {
        VStack(spacing: 16) {
            if activeCall == nil {
                SoftphoneCallingTabControl(selectedTab: $selectedTab)
                    .frame(maxWidth: 430)
            }

            Group {
                if let activeCall {
                    SoftphoneKeypadScreen(
                        dialPad: $dialPad,
                        activeCall: activeCall,
                        onCall: onCall,
                        onHangUp: onHangUp,
                        onToggleMute: onToggleMute,
                        onToggleHold: onToggleHold,
                        onSendDTMFDigit: onSendDTMFDigit
                    )
                } else if selectedTab == .contacts {
                    SoftphoneContactsScreen(
                        contactStore: contactStore,
                        favourites: favourites,
                        onToggleFavourite: toggleFavourite,
                        onCall: onCall
                    )
                } else if selectedTab == .favourites {
                    SoftphoneFavouritesScreen(
                        contactStore: contactStore,
                        favourites: favourites,
                        onToggleFavourite: toggleFavourite,
                        onCall: onCall
                    )
                } else {
                    SoftphoneKeypadScreen(
                        dialPad: $dialPad,
                        activeCall: nil,
                        onCall: onCall,
                        onHangUp: onHangUp,
                        onToggleMute: onToggleMute,
                        onToggleHold: onToggleHold,
                        onSendDTMFDigit: onSendDTMFDigit
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: activeCall?.id) { id in
            if id != nil {
                selectedTab = .keypad
            }
        }
    }

    private var favourites: SoftphoneContactFavourites {
        SoftphoneContactFavourites(rawValue: favouriteContactIDsRawValue)
    }

    private func toggleFavourite(_ row: SoftphoneCallingContactRowModel) {
        var updatedFavourites = favourites
        updatedFavourites.toggle(row)
        favouriteContactIDsRawValue = updatedFavourites.rawValue
    }

}

private struct SoftphoneCallingTabControl: View {
    @Binding var selectedTab: SoftphoneCallingTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SoftphoneCallingTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? SoftphoneTheme.text : SoftphoneTheme.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(selectedTab == tab ? SoftphoneTheme.selectedControlBackground : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Show \(tab.title.lowercased())")
            }
        }
        .padding(3)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneContactsScreen: View {
    @ObservedObject var contactStore: SoftphoneContactBrowserStore
    let favourites: SoftphoneContactFavourites
    let onToggleFavourite: (SoftphoneCallingContactRowModel) -> Void
    let onCall: (String) -> Void

    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SoftphoneSearchTextField(text: $query, placeholder: "Search contacts")
                    .frame(width: 420)
                Button {
                    contactStore.refreshIfAuthorized(force: true)
                } label: {
                    if contactStore.isSyncingContacts {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 34, height: 34)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoftphoneTheme.muted)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                .help("Refresh contacts")
                .disabled(contactStore.accessState != .authorized || contactStore.isSyncingContacts)
            }
            .frame(maxWidth: .infinity)

            if contactStore.isSyncingContacts && contactStore.hasLoadedContacts {
                Label("Syncing contacts", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoftphoneTheme.muted)
            }

            content
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            contactStore.refreshIfAuthorized()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch contactStore.accessState {
        case .idle:
            SoftphoneContactsAccessPrompt(onRequestAccess: contactStore.requestAccess)
        case .requesting:
            SoftphoneEmptyState(title: "Requesting contacts", subtitle: "Waiting for macOS permission.")
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .denied:
            VStack(spacing: 14) {
                SoftphoneEmptyState(title: "Contacts unavailable", subtitle: "Enable Contacts access for SIPMan in System Settings.")
                    .frame(maxHeight: 140)
                Button {
                    openContactsPrivacySettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle(width: 170))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SoftphoneTheme.rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .failed(let message):
            SoftphoneEmptyState(title: "Contacts failed", subtitle: message)
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .authorized:
            let rows = contactStore.model.rows(matching: query)
            if contactStore.isSyncingContacts && !contactStore.hasLoadedContacts {
                SoftphoneContactsSyncingView()
            } else if rows.isEmpty {
                SoftphoneEmptyState(title: emptyContactsTitle, subtitle: emptyContactsSubtitle)
                    .background(SoftphoneTheme.rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(rows) { row in
                            SoftphoneContactRow(
                                row: row,
                                isFavourite: favourites.contains(row),
                                onToggleFavourite: {
                                    onToggleFavourite(row)
                                }
                            ) {
                                onCall(row.number)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var emptyContactsTitle: String {
        query.isEmpty ? "No phone numbers" : "No contacts"
    }

    private var emptyContactsSubtitle: String {
        if !query.isEmpty {
            return "No contacts match this search."
        }

        if contactStore.loadedContactCount == 0 {
            return "SIPMan has Contacts access, but macOS returned no contacts."
        }

        if contactStore.loadedPhoneNumberCount == 0 {
            return "Loaded \(contactStore.loadedContactCount) contacts, but none had phone numbers."
        }

        return "Loaded \(contactStore.loadedContactCount) contacts and \(contactStore.loadedPhoneNumberCount) phone numbers, but none were callable."
    }

    private func openContactsPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct SoftphoneFavouritesScreen: View {
    @ObservedObject var contactStore: SoftphoneContactBrowserStore
    let favourites: SoftphoneContactFavourites
    let onToggleFavourite: (SoftphoneCallingContactRowModel) -> Void
    let onCall: (String) -> Void

    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SoftphoneSearchTextField(text: $query, placeholder: "Search favourites")
                    .frame(width: 420)
                Button {
                    contactStore.refreshIfAuthorized(force: true)
                } label: {
                    if contactStore.isSyncingContacts {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 34, height: 34)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoftphoneTheme.muted)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                .help("Refresh contacts")
                .disabled(contactStore.accessState != .authorized || contactStore.isSyncingContacts)
            }
            .frame(maxWidth: .infinity)

            if contactStore.isSyncingContacts && contactStore.hasLoadedContacts {
                Label("Syncing contacts", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoftphoneTheme.muted)
            }

            content
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            contactStore.refreshIfAuthorized()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch contactStore.accessState {
        case .idle:
            SoftphoneContactsAccessPrompt(onRequestAccess: contactStore.requestAccess)
        case .requesting:
            SoftphoneEmptyState(title: "Requesting contacts", subtitle: "Waiting for macOS permission.")
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .denied:
            SoftphoneEmptyState(title: "Contacts unavailable", subtitle: "Enable Contacts access for SIPMan in System Settings.")
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .failed(let message):
            SoftphoneEmptyState(title: "Contacts failed", subtitle: message)
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        case .authorized:
            let rows = contactStore.model.rows(withIDs: favourites.ids, matching: query)
            if contactStore.isSyncingContacts && !contactStore.hasLoadedContacts {
                SoftphoneContactsSyncingView()
            } else if rows.isEmpty {
                SoftphoneFavouritesEmptyState()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(rows) { row in
                            SoftphoneContactRow(
                                row: row,
                                isFavourite: true,
                                onToggleFavourite: {
                                    onToggleFavourite(row)
                                }
                            ) {
                                onCall(row.number)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct SoftphoneFavouritesEmptyState: View {
    var body: some View {
        Text("No favourites")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(SoftphoneTheme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct SoftphoneContactsAccessPrompt: View {
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SoftphoneTheme.muted)
            Text("Use local contacts")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SoftphoneTheme.text)
            Button {
                onRequestAccess()
            } label: {
                Label("Allow Contacts", systemImage: "person.crop.circle")
            }
            .buttonStyle(SoftphoneSecondaryButtonStyle(width: 170))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneContactsSyncingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Syncing contacts")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(SoftphoneTheme.text)
            Text("Reading local contacts from macOS.")
                .font(.system(size: 12))
                .foregroundStyle(SoftphoneTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneContactRow: View {
    let row: SoftphoneCallingContactRowModel
    let isFavourite: Bool
    let onToggleFavourite: () -> Void
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(SoftphoneTheme.muted)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SoftphoneTheme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(row.label)
                    Text(row.displayNumber)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SoftphoneTheme.muted)
                .lineLimit(1)
            }

            Spacer()

            Button {
                onToggleFavourite()
            } label: {
                Image(systemName: isFavourite ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isFavourite ? SoftphoneTheme.gold : SoftphoneTheme.muted)
                    .frame(width: 34, height: 30)
            }
            .buttonStyle(.plain)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            .help(isFavourite ? "Remove favourite" : "Add favourite")

            Button {
                onCall()
            } label: {
                Image(systemName: "phone.fill")
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 30)
                    .background(SoftphoneTheme.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Call \(row.displayNumber)")
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneSearchTextField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SoftphoneTheme.placeholder)
                .frame(width: 16)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(SoftphoneTheme.text)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SoftphoneTheme.placeholder)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        .onAppear {
            DispatchQueue.main.async {
                isFocused = false
            }
        }
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
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
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
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
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
    let onToggleHold: (String) -> Void
    let onSendDTMFDigit: (String, String) -> Void

    private let keys = SoftphoneKeypadKey.dialingKeys

    var body: some View {
        VStack(spacing: verticalSpacing) {
            if let activeCall {
                SoftphoneInlineCallHeader(call: activeCall)
            }

            if activeCall == nil {
                keypadDisplay
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(keyWidth), spacing: keySpacing), count: 3), spacing: keySpacing) {
                ForEach(keys) { key in
                    SoftphoneKeypadButton(
                        key: key,
                        keyWidth: keyWidth,
                        keyHeight: keyHeight,
                        keyLabelSpacing: keyLabelSpacing,
                        keyDigitFontSize: keyDigitFontSize,
                        keyLetterFontSize: keyLetterFontSize,
                        keyLetterHeight: keyLetterHeight,
                        keyCornerRadius: keyCornerRadius
                    ) {
                        appendKeypadValue(key.value)
                    } onLongPress: {
                        appendKeypadValue(key.longPressValue ?? key.value)
                    }
                }
            }
            .frame(width: keypadBlockWidth)

            callControls
        }
        .frame(width: keypadBlockWidth)
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
        isInCall ? 9 : 12
    }

    private var keypadBlockWidth: CGFloat {
        350
    }

    private var keyWidth: CGFloat {
        (keypadBlockWidth - (keySpacing * 2)) / 3
    }

    private var keyHeight: CGFloat {
        isInCall ? 52 : 56
    }

    private var keySpacing: CGFloat {
        isInCall ? 9 : 10
    }

    private var keyLabelSpacing: CGFloat {
        isInCall ? 2 : 3
    }

    private var keyDigitFontSize: CGFloat {
        isInCall ? 22 : 24
    }

    private var keyLetterFontSize: CGFloat {
        isInCall ? 9 : 10
    }

    private var keyLetterHeight: CGFloat {
        isInCall ? 8 : 10
    }

    private var keyCornerRadius: CGFloat {
        8
    }

    private var keypadDisplay: some View {
        Text(displayText)
            .font(.system(size: displayFontSize, weight: .semibold))
            .foregroundStyle(displayText == placeholderText ? SoftphoneTheme.placeholder : SoftphoneTheme.text)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, isInCall ? 14 : 18)
            .frame(width: keypadBlockWidth)
            .frame(height: isInCall ? 40 : 50)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }

    private var displayFontSize: CGFloat {
        if displayText == placeholderText {
            return isInCall ? 16 : 20
        }
        return isInCall ? 22 : 26
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
                    onToggleHold(activeCall.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: activeCall.isOnHold ? "play.fill" : "pause.fill")
                        Text(activeCall.isOnHold ? "Release" : "Hold")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle())
                .help(activeCall.isOnHold ? "Release hold" : "Put call on hold")

                Button {
                    onHangUp(activeCall.id)
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 104, height: 44)
                        .background(SoftphoneTheme.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Hang up")
            }
            .frame(width: keypadBlockWidth)
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
                        .frame(width: 72, height: 46)
                        .background(dialPad.canCall ? SoftphoneTheme.green : SoftphoneTheme.placeholder)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!dialPad.canCall)

                Button("Delete") {
                    dialPad.deleteLast()
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle())
            }
            .frame(width: keypadBlockWidth)
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

private struct SoftphoneKeypadButton: View {
    let key: SoftphoneKeypadKey
    let keyWidth: CGFloat
    let keyHeight: CGFloat
    let keyLabelSpacing: CGFloat
    let keyDigitFontSize: CGFloat
    let keyLetterFontSize: CGFloat
    let keyLetterHeight: CGFloat
    let keyCornerRadius: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        VStack(spacing: keyLabelSpacing) {
            Text(key.value)
                .font(.system(size: keyDigitFontSize, weight: .medium))
            Text(key.letters)
                .font(.system(size: keyLetterFontSize, weight: .bold))
                .foregroundStyle(SoftphoneTheme.placeholder)
                .frame(height: keyLetterHeight)
        }
        .frame(width: keyWidth, height: keyHeight)
        .background(SoftphoneTheme.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: keyCornerRadius, style: .continuous))
        .gesture(
            LongPressGesture(minimumDuration: 0.45)
                .exclusively(before: TapGesture())
                .onEnded { value in
                    switch value {
                    case .first:
                        onLongPress()
                    case .second:
                        onTap()
                    }
                }
        )
        .accessibilityLabel(key.letters.isEmpty ? key.value : "\(key.value) \(key.letters)")
        .accessibilityAddTraits(.isButton)
        .help(helpText)
    }

    private var helpText: String {
        guard let longPressValue = key.longPressValue else { return key.value }
        return "Hold for \(longPressValue)"
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneMessagesScreen: View {
    @ObservedObject var messageStore: SoftphoneMessageStore
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    SoftphoneSearchTextField(text: $searchText, placeholder: "Search conversations")
                    Button {
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SoftphoneTheme.text)
                    .background(SoftphoneTheme.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                    .help("New message")
                    .disabled(true)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)

                if filteredConversations.isEmpty {
                    VStack {
                        SoftphoneEmptyState(
                            title: emptyTitle,
                            subtitle: emptySubtitle
                        )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 44)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                SoftphoneConversationRow(
                                    conversation: conversation,
                                    isSelected: conversation.id == messageStore.selectedConversationId
                                ) {
                                    messageStore.selectConversation(id: conversation.id)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 332)
            .background(SoftphoneTheme.sidebarBackground)
            Divider()
            VStack(spacing: 0) {
                if let selectedConversation = messageStore.conversations.first(where: { $0.id == messageStore.selectedConversationId }) {
                    SoftphoneMessageHeader(conversation: selectedConversation)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            ForEach(messageStore.messages) { message in
                                SoftphoneMessageBubble(message: message)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 26)
                    }
                    .background(SoftphoneTheme.messageCanvas)
                    SoftphoneMessageComposerPlaceholder()
                } else {
                    SoftphoneTheme.messageCanvas
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SoftphoneTheme.windowBackground)
        }
        .background(SoftphoneTheme.windowBackground)
    }

    private var filteredConversations: [SoftphoneMessageConversationRowModel] {
        messageStore.conversations.filter { conversation in
            searchText.isEmpty ||
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                conversation.preview.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emptyTitle: String {
        messageStore.conversations.isEmpty ? "No messages" : "No matches"
    }

    private var emptySubtitle: String {
        messageStore.conversations.isEmpty
            ? "SIP MESSAGE conversations will appear here."
            : "Try a different search."
    }
}

private struct SoftphoneHistoryScreen: View {
    @ObservedObject var callHistoryStore: SoftphoneCallHistoryStore
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    let onPickRecord: (String) -> Void

    @State private var selectedFilter: SoftphoneCallHistoryFilter = .all
    @AppStorage(SoftphoneContactFavourites.storageKey) private var favouriteContactIDsRawValue = SoftphoneContactFavourites().rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                SoftphoneHistoryFilterControl(selectedFilter: $selectedFilter)
                Spacer()
            }
            .padding(.horizontal, 48)
            .padding(.top, 28)
            .padding(.bottom, 14)
            if filteredRows.isEmpty {
                SoftphoneEmptyState(title: emptyStateTitle, subtitle: emptyStateSubtitle)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(SoftphoneTheme.rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                    .padding(48)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(historySections) { section in
                            Text(section.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(SoftphoneTheme.muted)
                                .padding(.horizontal, 4)
                                .padding(.top, section == historySections.first ? 0 : 14)

                            ForEach(section.rows) { row in
                                SoftphoneCallHistoryRow(
                                    row: row,
                                    isFavourite: isFavourite(row),
                                    onToggleFavourite: {
                                        toggleFavourite(row)
                                    }
                                ) {
                                    onPickRecord(row.id)
                                }
                                .contextMenu {
                                    Button("Flow Diagram...") {
                                        SoftphoneSIPFlowDiagramWindowRegistry.shared.open(
                                            diagram: SoftphoneSIPFlowDiagramFactory.make(
                                                row: row,
                                                snapshot: diagnosticsStore.snapshot
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredRows: [SoftphoneCallHistoryRowModel] {
        callHistoryStore.rows(matching: selectedFilter)
    }

    private var historySections: [SoftphoneCallHistorySectionModel] {
        callHistoryStore.sections(matching: selectedFilter)
    }

    private var favourites: SoftphoneContactFavourites {
        SoftphoneContactFavourites(rawValue: favouriteContactIDsRawValue)
    }

    private func isFavourite(_ row: SoftphoneCallHistoryRowModel) -> Bool {
        guard let favouriteContactID = row.favouriteContactID else { return false }
        return favourites.contains(id: favouriteContactID)
    }

    private func toggleFavourite(_ row: SoftphoneCallHistoryRowModel) {
        guard let favouriteContactID = row.favouriteContactID else { return }
        var updatedFavourites = favourites
        updatedFavourites.toggle(id: favouriteContactID)
        favouriteContactIDsRawValue = updatedFavourites.rawValue
    }

    private var emptyStateTitle: String {
        selectedFilter == .all ? "No recent calls" : "No \(selectedFilter.title.lowercased()) calls"
    }

    private var emptyStateSubtitle: String {
        selectedFilter == .all ? "Completed and missed calls will appear here." : "Calls matching this filter will appear here."
    }
}

@MainActor
private final class SoftphoneSIPFlowDiagramWindowRegistry: NSObject, NSWindowDelegate {
    static let shared = SoftphoneSIPFlowDiagramWindowRegistry()

    private var controllers: [NSWindowController] = []

    func open(diagram: SoftphoneSIPFlowDiagramModel) {
        let content = SoftphoneSIPFlowDiagramWindow(diagram: diagram)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SIP Flow Diagram"
        window.contentView = NSHostingView(rootView: content)
        window.center()
        window.delegate = self

        let controller = NSWindowController(window: window)
        controllers.append(controller)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        controllers.removeAll { $0.window === closingWindow }
    }
}

private struct SoftphoneSIPFlowDiagramWindow: View {
    let diagram: SoftphoneSIPFlowDiagramModel

    @State private var zoom: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(diagram.title)
                        .font(.system(size: 15, weight: .bold))
                    Text(diagram.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(SoftphoneTheme.muted)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    zoom = max(0.7, zoom - 0.1)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Zoom out")

                Button {
                    zoom = min(1.6, zoom + 0.1)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Zoom in")

                Button("Copy") {
                    copyReport()
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle(width: 74))
                .help("Copy the flow as text")

                Button("Save...") {
                    saveReport()
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle(width: 78))
                .help("Save the flow as text")
            }
            .padding(14)
            .background(SoftphoneTheme.rowBackground)

            Divider()

            if diagram.events.isEmpty {
                SoftphoneEmptyState(title: "No SIP messages found", subtitle: "The retained SIP log does not contain signaling for this history row.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView([.horizontal, .vertical]) {
                    SoftphoneSIPFlowDiagramCanvas(diagram: diagram)
                        .scaleEffect(zoom, anchor: .topLeading)
                        .frame(
                            width: SoftphoneSIPFlowDiagramCanvas.preferredWidth * zoom,
                            height: SoftphoneSIPFlowDiagramCanvas.height(forEventCount: diagram.events.count) * zoom,
                            alignment: .topLeading
                        )
                        .padding(18)
                }
                .background(SoftphoneTheme.windowBackground)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagram.textReport, forType: .string)
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "sip-flow.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? diagram.textReport.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private struct SoftphoneSIPFlowDiagramCanvas: View {
    static let preferredWidth: CGFloat = 840

    let diagram: SoftphoneSIPFlowDiagramModel

    var body: some View {
        Canvas { context, size in
            let top: CGFloat = 62
            let bottom: CGFloat = 28
            let rowHeight: CGFloat = 44
            let laneXs = lanePositions(width: size.width)
            let diagramHeight = top + CGFloat(diagram.events.count) * rowHeight + bottom

            context.draw(
                Text("Time")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(SoftphoneTheme.muted),
                at: CGPoint(x: 54, y: 22),
                anchor: .trailing
            )

            for (index, lane) in diagram.lanes.enumerated() {
                let x = laneXs[index]
                var lanePath = Path()
                lanePath.move(to: CGPoint(x: x, y: top - 22))
                lanePath.addLine(to: CGPoint(x: x, y: diagramHeight - bottom))
                context.stroke(lanePath, with: .color(SoftphoneTheme.hairline), lineWidth: 1)
                context.draw(
                    Text(lane)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(SoftphoneTheme.text),
                    at: CGPoint(x: x, y: 22),
                    anchor: .center
                )
            }

            for (index, event) in diagram.events.enumerated() {
                let y = top + CGFloat(index) * rowHeight
                context.draw(
                    Text(event.timestamp)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(SoftphoneTheme.muted),
                    at: CGPoint(x: 54, y: y),
                    anchor: .trailing
                )

                let start = CGPoint(x: laneXs[event.sourceLaneIndex], y: y)
                let end = CGPoint(x: laneXs[event.destinationLaneIndex], y: y)
                drawArrow(from: start, to: end, in: &context)

                let labelPoint = CGPoint(x: (start.x + end.x) / 2, y: y - 10)
                context.draw(
                    Text(event.caption)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(SoftphoneTheme.text),
                    at: labelPoint,
                    anchor: .center
                )

                let detail = [event.isRetransmit ? "retransmit" : nil, event.detail.isEmpty ? nil : event.detail]
                    .compactMap { $0 }
                    .joined(separator: " · ")
                if !detail.isEmpty {
                    context.draw(
                        Text(detail)
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(SoftphoneTheme.muted),
                        at: CGPoint(x: (start.x + end.x) / 2, y: y + 11),
                        anchor: .center
                    )
                }
            }
        }
        .frame(width: Self.preferredWidth, height: Self.height(forEventCount: diagram.events.count))
    }

    static func height(forEventCount eventCount: Int) -> CGFloat {
        62 + CGFloat(max(eventCount, 1)) * 44 + 28
    }

    private func lanePositions(width: CGFloat) -> [CGFloat] {
        [width * 0.23, width * 0.57, width * 0.91]
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: inout GraphicsContext) {
        let direction: CGFloat = end.x >= start.x ? 1 : -1
        let lineEnd = CGPoint(x: end.x - (direction * 10), y: end.y)
        var path = Path()
        path.move(to: start)
        path.addLine(to: lineEnd)
        context.stroke(path, with: .color(SoftphoneTheme.blue), lineWidth: 1.5)

        var head = Path()
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - direction * 10, y: end.y - 5))
        head.addLine(to: CGPoint(x: end.x - direction * 10, y: end.y + 5))
        head.closeSubpath()
        context.fill(head, with: .color(SoftphoneTheme.blue))
    }
}

private enum SoftphoneSettingsTab: String, CaseIterable, Identifiable {
    case account
    case diagnostics
    case sipLog
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account:
            return "Account"
        case .diagnostics:
            return "Diagnostics"
        case .sipLog:
            return "SIP Log"
        case .tools:
            return "Tools"
        }
    }
}

private enum SoftphoneSIPPingTransport: String, CaseIterable, Identifiable {
    case udp = "udp"
    case tcp = "tcp"
    case tls = "tls"

    var id: String { rawValue }

    var title: String { rawValue.uppercased() }
}

private struct SoftphoneSettingsScreen: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    let onSIPPing: (String, String, @escaping ([String: Any]) -> Void) -> Void
    let onSaveNetworkSettings: ([String: Any]) -> Void
    let onSaveAccountSettings: ([String: Any]) -> Void
    let onLogOut: () -> Void

    @State private var selectedTab: SoftphoneSettingsTab = .account

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SoftphoneSettingsTabControl(selectedTab: $selectedTab)

            switch selectedTab {
            case .account:
                SoftphoneAccountSettingsPane(
                    diagnosticsStore: diagnosticsStore,
                    onSaveNetworkSettings: onSaveNetworkSettings,
                    onSaveAccountSettings: onSaveAccountSettings,
                    onLogOut: onLogOut
                )
            case .diagnostics:
                SoftphoneDiagnosticsSettingsPane(diagnosticsStore: diagnosticsStore)
            case .sipLog:
                SoftphoneSIPLogSettingsPane(diagnosticsStore: diagnosticsStore)
            case .tools:
                SoftphoneToolsSettingsPane(onSIPPing: onSIPPing)
            }

            Spacer()
        }
    }

}

private struct SoftphoneSettingsTabControl: View {
    @Binding var selectedTab: SoftphoneSettingsTab

    var body: some View {
        HStack(spacing: 2) {
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
        .padding(3)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneAccountSettingsPane: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore
    let onSaveNetworkSettings: ([String: Any]) -> Void
    let onSaveAccountSettings: ([String: Any]) -> Void
    let onLogOut: () -> Void

    @State private var sipAddress = ""
    @State private var accountDomain = ""
    @State private var username = ""
    @State private var password = ""
    @State private var selectedAccountTransport: SoftphoneAccountTransport = .udp
    @State private var accountPort = ""
    @State private var stunServerAddress = ""
    @State private var turnServerAddress = ""
    @State private var usesICE = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SoftphoneEditableField(
                            label: "SIP address",
                            placeholder: "user@example.com",
                            text: $sipAddress
                        )
                        SoftphoneEditableField(
                            label: "Domain",
                            placeholder: "example.com",
                            text: $accountDomain
                        )
                    }
                    HStack(spacing: 12) {
                        SoftphoneEditableField(
                            label: "Username",
                            placeholder: "user",
                            text: $username
                        )
                        SoftphoneSecureEditableField(
                            label: "Password",
                            placeholder: diagnosticsStore.snapshot.passwordStatus,
                            text: $password
                        )
                    }
                    HStack(alignment: .bottom, spacing: 12) {
                        SoftphoneAccountTransportPicker(selectedTransport: $selectedAccountTransport)
                            .frame(width: 126)
                        SoftphoneEditableField(
                            label: "Port",
                            placeholder: selectedAccountTransport.defaultPort,
                            text: $accountPort
                        )
                        .frame(width: 112)

                        Button {
                            saveAccountSettings()
                        } label: {
                            Label("Save Account", systemImage: "checkmark")
                        }
                        .buttonStyle(SoftphoneSecondaryButtonStyle(width: 144))
                        .disabled(!canSaveAccountSettings)
                        .help("Save account details")

                        Button {
                            onLogOut()
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .buttonStyle(SoftphoneSecondaryButtonStyle(width: 118, foregroundColor: SoftphoneTheme.red))
                        .help("Log out of this SIP account")

                        Spacer()
                    }
                }
                .padding(12)
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))

                SoftphoneNATTraversalSettingsPane(
                    stunServerAddress: $stunServerAddress,
                    turnServerAddress: $turnServerAddress,
                    usesICE: $usesICE,
                    canSave: hasNetworkSettingsChanges,
                    onSave: saveNetworkSettings
                )
                SoftphoneAppearanceSettingsRow()
                SoftphoneVersionSettingsRow()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            resetAccountSettings()
            resetNetworkSettings()
        }
        .onChange(of: diagnosticsStore.snapshot.sipAddress) { _ in resetAccountSettings() }
        .onChange(of: diagnosticsStore.snapshot.domain) { _ in resetAccountSettings() }
        .onChange(of: diagnosticsStore.snapshot.username) { _ in resetAccountSettings() }
        .onChange(of: diagnosticsStore.snapshot.transport) { _ in resetAccountSettings() }
        .onChange(of: diagnosticsStore.snapshot.port) { _ in resetAccountSettings() }
        .onChange(of: diagnosticsStore.snapshot.stunServerAddress) { _ in resetNetworkSettings() }
        .onChange(of: diagnosticsStore.snapshot.turnServerAddress) { _ in resetNetworkSettings() }
        .onChange(of: diagnosticsStore.snapshot.usesICE) { _ in resetNetworkSettings() }
    }

    private var canSaveAccountSettings: Bool {
        !accountDomain.trimmed.isEmpty &&
            !username.trimmed.isEmpty &&
            normalizedAccountPort != nil &&
            hasAccountSettingsChanges
    }

    private var hasAccountSettingsChanges: Bool {
        sipAddress.trimmed != diagnosticsStore.snapshot.sipAddress ||
            accountDomain.trimmed != diagnosticsStore.snapshot.domain ||
            username.trimmed != diagnosticsStore.snapshot.username ||
            selectedAccountTransport.rawValue != diagnosticsStore.snapshot.transport.trimmed.uppercased() ||
            accountPortDisplayValue != diagnosticsStore.snapshot.port ||
            !password.isEmpty
    }

    private var normalizedAccountPort: Int? {
        let trimmedPort = accountPort.trimmed
        guard !trimmedPort.isEmpty else { return 0 }
        guard let port = Int(trimmedPort), (1...65535).contains(port) else { return nil }
        return port
    }

    private var accountPortDisplayValue: String {
        guard let port = normalizedAccountPort, port > 0 else { return "Default" }
        return "\(port)"
    }

    private var hasNetworkSettingsChanges: Bool {
        SoftphoneServerAddress(stunServerAddress).displayValue != diagnosticsStore.snapshot.stunServerAddress ||
            SoftphoneServerAddress(turnServerAddress).displayValue != diagnosticsStore.snapshot.turnServerAddress ||
            usesICE != diagnosticsStore.snapshot.usesICE
    }

    private func resetAccountSettings() {
        sipAddress = diagnosticsStore.snapshot.sipAddress
        accountDomain = diagnosticsStore.snapshot.domain
        username = diagnosticsStore.snapshot.username
        password = ""
        selectedAccountTransport = SoftphoneAccountTransport(displayValue: diagnosticsStore.snapshot.transport)
        accountPort = diagnosticsStore.snapshot.port == "Default" ? "" : diagnosticsStore.snapshot.port
    }

    private func saveAccountSettings() {
        let port = normalizedAccountPort ?? 0
        onSaveAccountSettings([
            AKSIPAccountKeys.sipAddress: sipAddress.trimmed,
            AKSIPAccountKeys.domain: accountDomain.trimmed,
            AKSIPAccountKeys.username: username.trimmed,
            AKSIPAccountKeys.transport: selectedAccountTransport.rawValue,
            AKSIPAccountKeys.proxyPort: port,
            SoftphoneAccountSettingsKey.password: password
        ])
        password = ""
    }

    private func resetNetworkSettings() {
        stunServerAddress = diagnosticsStore.snapshot.stunServerAddress
        turnServerAddress = diagnosticsStore.snapshot.turnServerAddress
        usesICE = diagnosticsStore.snapshot.usesICE
    }

    private func saveNetworkSettings() {
        let stunAddress = SoftphoneServerAddress(stunServerAddress)
        let turnAddress = SoftphoneServerAddress(turnServerAddress)
        let effectiveUsesICE = usesICE || !turnAddress.host.isEmpty
        onSaveNetworkSettings([
            UserDefaultsKeys.stunServerHost: stunAddress.host,
            UserDefaultsKeys.stunServerPort: stunAddress.port,
            UserDefaultsKeys.turnServerHost: turnAddress.host,
            UserDefaultsKeys.turnServerPort: turnAddress.port,
            UserDefaultsKeys.useICE: effectiveUsesICE
        ])
    }
}

private struct SoftphoneNATTraversalSettingsPane: View {
    @Binding var stunServerAddress: String
    @Binding var turnServerAddress: String
    @Binding var usesICE: Bool
    let canSave: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("NAT traversal")
                .font(.system(size: 13, weight: .semibold))
                Text("Optional ICE, STUN, and TURN settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(SoftphoneTheme.muted)
            }
            HStack(spacing: 12) {
                SoftphoneEditableField(
                    label: "STUN server",
                    placeholder: "stun.example.com:3478",
                    text: $stunServerAddress
                )
                SoftphoneEditableField(
                    label: "TURN server",
                    placeholder: "turn.example.com:3478",
                    text: $turnServerAddress
                )
            }
            HStack(spacing: 12) {
                Toggle("Use ICE", isOn: $usesICE)
                    .toggleStyle(.switch)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button {
                    onSave()
                } label: {
                    Label("Save Network", systemImage: "checkmark")
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle(width: 142))
                .disabled(!canSave)
                .help("Save NAT traversal settings")
            }
        }
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneAppearanceSettingsRow: View {
    @AppStorage(SoftphoneAppearance.userDefaultsKey) private var appearanceModeRawValue = SoftphoneAppearanceMode.light.rawValue

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: appearanceMode.isDarkModeEnabled ? "moon.fill" : "sun.max.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(appearanceMode.isDarkModeEnabled ? SoftphoneTheme.blue : SoftphoneTheme.amber)
                .frame(width: 32, height: 32)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Dark mode")
                    .font(.system(size: 13, weight: .semibold))
                Text("Use SIPMan's dark palette.")
                    .font(.system(size: 12))
                    .foregroundStyle(SoftphoneTheme.muted)
            }

            Spacer()

            Toggle("", isOn: isDarkModeEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }

    private var appearanceMode: SoftphoneAppearanceMode {
        SoftphoneAppearanceMode(rawValue: appearanceModeRawValue) ?? .light
    }

    private var isDarkModeEnabled: Binding<Bool> {
        Binding(
            get: { appearanceMode.isDarkModeEnabled },
            set: { isEnabled in
                appearanceModeRawValue = SoftphoneAppearanceMode(isDarkModeEnabled: isEnabled).rawValue
            }
        )
    }
}

private struct SoftphoneVersionSettingsRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SoftphoneTheme.blue)
                .frame(width: 32, height: 32)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Version")
                    .font(.system(size: 13, weight: .semibold))
                Text(displayVersion)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SoftphoneTheme.muted)
            }

            Spacer()
        }
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }

    private var displayVersion: String {
        let info = Bundle.main.infoDictionary
        let marketingVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(marketingVersion) (\(buildNumber))"
    }
}

private struct SoftphoneDiagnosticsSettingsPane: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SoftphoneSectionHeader(title: "Diagnostics", subtitle: "Registration, media path, and live call quality.")
                HStack(spacing: 8) {
                    SoftphoneDiagnosticTile(label: "Registration", value: diagnosticsStore.snapshot.registrationState.title)
                    SoftphoneDiagnosticTile(label: "Last registered", value: diagnosticsStore.snapshot.lastRegistration)
                    SoftphoneDiagnosticTile(
                        label: "Transport",
                        value: "\(diagnosticsStore.snapshot.transport) - \(diagnosticsStore.snapshot.port)"
                    )
                }
                SoftphoneLiveCallDiagnosticsPane(activeCall: diagnosticsStore.snapshot.activeCall)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SoftphoneToolsSettingsPane: View {
    let onSIPPing: (String, String, @escaping ([String: Any]) -> Void) -> Void

    @State private var destination = ""
    @State private var selectedTransport: SoftphoneSIPPingTransport = .udp
    @State private var isRunning = false
    @State private var result: SoftphoneSIPPingResultModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SoftphoneSectionHeader(title: "Tools", subtitle: "One-off SIP probes for field diagnostics.")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        SoftphoneEditableField(
                            label: "SIP target",
                            placeholder: "user@domain",
                            text: $destination
                        )
                        .frame(minWidth: 260)

                        SoftphoneTransportPicker(selectedTransport: $selectedTransport)
                            .frame(width: 190)
                    }

                    HStack {
                        Button {
                            sendPing()
                        } label: {
                            Label(isRunning ? "Pinging" : "Send OPTIONS", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .buttonStyle(SoftphoneSecondaryButtonStyle(width: 156))
                        .disabled(!canSend)
                        .help("Send a SIP OPTIONS ping")

                        Spacer()
                    }

                    if let result {
                        SoftphoneSIPPingResultPanel(result: result)
                    } else {
                        SoftphoneEmptyState(title: "No SIP ping yet", subtitle: "Send OPTIONS to capture a response or timeout.")
                    }
                }
                .padding(12)
                .background(SoftphoneTheme.rowBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canSend: Bool {
        !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning
    }

    private func sendPing() {
        let target = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        isRunning = true
        result = nil
        onSIPPing(target, selectedTransport.rawValue) { dictionary in
            result = SoftphoneSIPPingResultModel(dictionary: dictionary)
            isRunning = false
        }
    }
}

private struct SoftphoneEditableField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SoftphoneTheme.muted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        }
    }
}

private struct SoftphoneSecureEditableField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SoftphoneTheme.muted)
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoftphoneTheme.muted)
                .help(isRevealed ? "Hide password" : "Show password")
            }
            .padding(.leading, 13)
            .padding(.trailing, 9)
            .frame(height: 46)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        }
    }
}

private struct SoftphoneTransportPicker: View {
    @Binding var selectedTransport: SoftphoneSIPPingTransport

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Transport")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SoftphoneTheme.muted)
            HStack(spacing: 3) {
                ForEach(SoftphoneSIPPingTransport.allCases) { transport in
                    Button {
                        selectedTransport = transport
                    } label: {
                        Text(transport.title)
                            .softphoneSegment(isSelected: selectedTransport == transport)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .help("Use \(transport.title)")
                }
            }
            .padding(4)
            .frame(height: 46)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        }
    }
}

private struct SoftphoneAccountTransportPicker: View {
    @Binding var selectedTransport: SoftphoneAccountTransport

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Transport")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SoftphoneTheme.muted)
            Menu {
                ForEach(SoftphoneAccountTransport.allCases) { transport in
                    Button {
                        selectedTransport = transport
                    } label: {
                        if selectedTransport == transport {
                            Label(transport.title, systemImage: "checkmark")
                        } else {
                            Text(transport.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedTransport.title)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SoftphoneTheme.placeholder)
                }
                .padding(.horizontal, 13)
                .frame(height: 46)
                .frame(maxWidth: .infinity)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .help("Choose account transport")
        }
    }
}

private struct SoftphoneSIPPingResultPanel: View {
    let result: SoftphoneSIPPingResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SoftphoneDiagnosticTile(label: "Status", value: result.status)
                SoftphoneDiagnosticTile(label: "Transport", value: result.transport.uppercased())
                SoftphoneDiagnosticTile(label: "Elapsed", value: result.elapsed)
            }
            SoftphoneLabeledField(label: "Target", value: result.target)
            SoftphoneLabeledField(label: "Summary", value: result.summary)
            if !result.detail.isEmpty {
                SoftphoneLabeledField(label: "Detail", value: result.detail)
            }
            if !result.rawResponse.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Response")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SoftphoneTheme.muted)
                    ScrollView {
                        Text(result.rawResponse)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .frame(minHeight: 110, maxHeight: 170)
                    .background(SoftphoneTheme.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                }
            }
        }
    }
}

private struct SoftphoneSIPLogSettingsPane: View {
    @ObservedObject var diagnosticsStore: SoftphoneDiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                SoftphoneSectionHeader(title: "Live SIP Log", subtitle: "")
                Spacer()
                Button {
                    diagnosticsStore.clearSIPLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(SoftphoneSecondaryButtonStyle(width: 92))
                .disabled(diagnosticsStore.snapshot.sipLogEntries.isEmpty)
                .help("Clear the live SIP log")
            }

            if diagnosticsStore.snapshot.sipLogEntries.isEmpty {
                SoftphoneEmptyState(title: "No SIP log entries", subtitle: "PJSIP messages will appear here as the stack runs.")
                    .background(SoftphoneTheme.rowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            } else {
                SoftphoneSIPLogPanel(entries: diagnosticsStore.snapshot.sipLogEntries)
            }
        }
    }
}

private struct SoftphoneSIPLogPanel: View {
    let entries: [SoftphoneSIPLogEntryModel]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(entries) { entry in
                        SoftphoneSIPLogRow(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SoftphoneTheme.rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            .onChange(of: entries.last?.id) { id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }
}

private struct SoftphoneSIPLogRow: View {
    let entry: SoftphoneSIPLogEntryModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp)
                .foregroundStyle(SoftphoneTheme.placeholder)
                .frame(width: 76, alignment: .leading)
            Text("L\(entry.level)")
                .foregroundStyle(levelColor)
                .frame(width: 24, alignment: .leading)
            Text(entry.message)
                .foregroundStyle(SoftphoneTheme.text)
                .textSelection(.enabled)
        }
        .font(.system(size: 11, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var levelColor: Color {
        entry.level <= 2 ? SoftphoneTheme.amber : SoftphoneTheme.muted
    }
}

private struct SoftphoneLiveCallDiagnosticsPane: View {
    let activeCall: SoftphoneLiveCallDiagnosticsModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live call")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                if let activeCall {
                    SoftphoneQualityPill(quality: activeCall.quality)
                }
            }

            if let activeCall {
                HStack(spacing: 8) {
                    SoftphoneDiagnosticTile(label: "Remote party", value: activeCall.remoteParty)
                    SoftphoneDiagnosticTile(label: "Status", value: activeCall.status)
                    SoftphoneDiagnosticTile(label: "Duration", value: activeCall.duration.isEmpty ? "--" : activeCall.duration)
                    SoftphoneDiagnosticTile(label: "Sampled", value: activeCall.sampledAt)
                }

                if activeCall.statsRows.isEmpty {
                    SoftphoneEmptyState(title: "Stats pending", subtitle: "Media diagnostics will appear once RTP is active.")
                } else {
                    SoftphoneCallStatsTable(rows: activeCall.statsRows)
                }
            } else {
                SoftphoneEmptyState(title: "No active call", subtitle: "Jitter, packet, RTP, and ICE diagnostics will appear during a live call.")
            }
        }
        .padding(12)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
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
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
        .padding(.trailing, trailingPadding)
    }
}

private struct SoftphoneConversationRow: View {
    let conversation: SoftphoneMessageConversationRowModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                SoftphoneAvatar(initials: initials(for: conversation.title))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(conversation.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SoftphoneTheme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(conversation.date)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SoftphoneTheme.placeholder)
                    }
                    Text(conversation.preview)
                        .font(.system(size: 13))
                        .foregroundStyle(SoftphoneTheme.muted)
                        .lineLimit(1)
                    Text("SMS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SoftphoneTheme.blue)
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 88)
            .background(isSelected ? SoftphoneTheme.selectedControlBackground : Color.clear)
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
        HStack(spacing: 16) {
            SoftphoneAvatar(initials: initials(for: conversation.title), size: 44)
            VStack(alignment: .leading, spacing: 5) {
                Text(conversation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SoftphoneTheme.text)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(conversation.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SoftphoneTheme.muted)
                        .lineLimit(1)
                    Text("SMS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SoftphoneTheme.blue)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(SoftphoneTheme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            Spacer()
            HStack(spacing: 14) {
                Button {
                } label: {
                    Image(systemName: "phone")
                        .font(.system(size: 19, weight: .medium))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoftphoneTheme.muted)
                .help("Call conversation")
                .disabled(true)

                Button {
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 21, weight: .bold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .foregroundStyle(SoftphoneTheme.muted)
                .help("Conversation options")
                .disabled(true)
            }
        }
        .padding(.horizontal, 28)
        .frame(height: 84)
    }

    private func initials(for value: String) -> String {
        let parts = value.split(separator: " ").prefix(2)
        let result = parts.compactMap(\.first).map(String.init).joined()
        return result.isEmpty ? "?" : result.uppercased()
    }
}

private struct SoftphoneMessageBubble: View {
    let message: SoftphoneMessageBubbleModel

    var body: some View {
        HStack {
            if message.isOutgoing {
                Spacer(minLength: 120)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(message.senderTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(message.isOutgoing ? SoftphoneTheme.blue : SoftphoneTheme.text)
                Text(message.body)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(SoftphoneTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if message.isOutgoing {
                        Text(message.deliveryState)
                    }
                    Spacer()
                    Text(message.date)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SoftphoneTheme.muted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: 560, alignment: .leading)
            .background(message.isOutgoing ? SoftphoneTheme.outgoingMessageBubble : SoftphoneTheme.incomingMessageBubble)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            if !message.isOutgoing {
                Spacer(minLength: 120)
            }
        }
    }
}

private struct SoftphoneMessageComposerPlaceholder: View {
    var body: some View {
        HStack(spacing: 12) {
            Button {
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(SoftphoneTheme.muted)
            .help("Emoji")
            .disabled(true)

            Text("SMS message")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(SoftphoneTheme.placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .frame(height: 50)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(SoftphoneTheme.blue, lineWidth: 1.8))
            Button {
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(SoftphoneTheme.sendButtonBackground)
            .clipShape(Circle())
            .disabled(true)
            .help("Send message")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(SoftphoneTheme.windowBackground)
    }
}

private struct SoftphoneAvatar: View {
    let initials: String
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(.system(size: size > 40 ? 16 : 13, weight: .bold))
            .foregroundStyle(SoftphoneTheme.text)
            .frame(width: size, height: size)
            .background(SoftphoneTheme.avatarBackground)
            .clipShape(Circle())
    }
}

private struct SoftphoneHistoryFilterControl: View {
    @Binding var selectedFilter: SoftphoneCallHistoryFilter

    var body: some View {
        HStack(spacing: 2) {
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
        .padding(3)
        .background(SoftphoneTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneCallHistoryRow: View {
    let row: SoftphoneCallHistoryRowModel
    let isFavourite: Bool
    let onToggleFavourite: () -> Void
    let onCall: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.symbolName)
                .foregroundStyle(row.isMissed ? SoftphoneTheme.red : SoftphoneTheme.blue)
                .frame(width: 36, height: 36)
                .background((row.isMissed ? SoftphoneTheme.red : SoftphoneTheme.blue).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(row.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(SoftphoneTheme.muted)
            }
            Spacer()
            if row.favouriteContactID != nil {
                Button {
                    onToggleFavourite()
                } label: {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isFavourite ? SoftphoneTheme.gold : SoftphoneTheme.muted)
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.plain)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
                .help(isFavourite ? "Remove favourite" : "Add favourite")
            }
            Button {
                onCall()
            } label: {
                Image(systemName: "phone.fill")
            }
            .buttonStyle(SoftphonePrimaryIconButtonStyle(color: SoftphoneTheme.green))
        }
        .padding(10)
        .background(SoftphoneTheme.rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(SoftphoneTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct SoftphoneSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(SoftphoneTheme.muted)
            }
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
                .font(.system(size: 13, weight: .medium))
                .frame(height: 40)
                .background(SoftphoneTheme.fieldBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
    }
}

private struct SoftphoneSecondaryButtonStyle: ButtonStyle {
    var width: CGFloat?
    var foregroundColor: Color = SoftphoneTheme.muted

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foregroundColor)
            .frame(width: width, height: 40)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(SoftphoneTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(SoftphoneTheme.hairline, lineWidth: 0.5))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct SoftphonePrimaryIconButtonStyle: ButtonStyle {
    var color: Color = SoftphoneTheme.blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension View {
    func softphoneSegment(isSelected: Bool) -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isSelected ? SoftphoneTheme.text : SoftphoneTheme.muted)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isSelected ? SoftphoneTheme.selectedControlBackground : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum SoftphoneTheme {
    static let text = adaptive(light: color(0.10, 0.12, 0.16), dark: color(0.90, 0.93, 0.96))
    static let muted = adaptive(light: color(0.39, 0.41, 0.44), dark: color(0.62, 0.67, 0.73))
    static let placeholder = adaptive(light: color(0.62, 0.63, 0.65), dark: color(0.45, 0.51, 0.58))
    static let blue = adaptive(light: color(0.25, 0.49, 0.86), dark: color(0.42, 0.65, 1.00))
    static let green = adaptive(light: color(0.14, 0.68, 0.34), dark: color(0.20, 0.78, 0.42))
    static let red = adaptive(light: color(0.88, 0.24, 0.22), dark: color(1.00, 0.38, 0.34))
    static let amber = adaptive(light: color(0.90, 0.55, 0.12), dark: color(1.00, 0.70, 0.22))
    static let gold = adaptive(light: color(0.93, 0.66, 0.10), dark: color(1.00, 0.76, 0.18))
    static let windowBackground = adaptive(light: color(0.98, 0.98, 0.97), dark: color(0.07, 0.09, 0.12))
    static let sidebarBackground = adaptive(light: color(0.96, 0.95, 0.93, 0.78), dark: color(0.10, 0.13, 0.17, 0.86))
    static let controlBackground = adaptive(light: color(1.00, 1.00, 1.00, 0.82), dark: color(0.14, 0.18, 0.23, 0.92))
    static let selectedControlBackground = adaptive(light: color(0.91, 0.91, 0.90, 0.92), dark: color(0.18, 0.23, 0.29, 0.96))
    static let fieldBackground = adaptive(light: color(0.96, 0.96, 0.95, 0.86), dark: color(0.11, 0.15, 0.20))
    static let rowBackground = adaptive(light: color(1.00, 1.00, 1.00, 0.68), dark: color(0.12, 0.16, 0.21, 0.88))
    static let hairline = adaptive(light: color(0.83, 0.83, 0.82, 0.72), dark: color(0.23, 0.28, 0.34, 0.85))
    static let messageCanvas = adaptive(light: color(0.94, 0.97, 0.98), dark: color(0.08, 0.12, 0.15))
    static let incomingMessageBubble = adaptive(light: color(0.98, 0.99, 1.00, 0.94), dark: color(0.13, 0.18, 0.23, 0.96))
    static let outgoingMessageBubble = adaptive(light: color(0.90, 0.96, 1.00, 0.96), dark: color(0.12, 0.23, 0.34, 0.96))
    static let avatarBackground = adaptive(light: color(0.92, 0.93, 0.94), dark: color(0.20, 0.25, 0.31))
    static let sendButtonBackground = adaptive(light: color(0.58, 0.70, 0.76), dark: color(0.35, 0.52, 0.62))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        let color = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
        return Color(nsColor: color)
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}
