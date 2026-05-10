//
//  SIPMessageConversation.swift
//  Telephone
//
//  Copyright © 2026 64 Characters
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

public struct SIPMessageConversation: Sendable {
    public let identifier: String
    public let accountUUID: String
    public let remote: URI

    public init(accountUUID: String, remote: URI) {
        self.identifier = SIPMessageConversation.identifier(accountUUID: accountUUID, remote: remote)
        self.accountUUID = accountUUID
        self.remote = remote
    }

    public static func identifier(accountUUID: String, remote: URI) -> String {
        return "\(accountUUID)|\(remoteAddress(remote))|\(remote.transport.stringValue)"
    }
}

extension SIPMessageConversation: Equatable {
    public static func ==(lhs: SIPMessageConversation, rhs: SIPMessageConversation) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

private func remoteAddress(_ remote: URI) -> String {
    return remote.user.isEmpty ? remote.address.stringValue : "\(remote.user)@\(remote.address)"
}
