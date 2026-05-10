//
//  SIPMessageContent.swift
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

public struct SIPMessageContent: Equatable, Sendable {
    public static let plainTextContentType = "text/plain"

    public let body: String
    public let contentType: String

    public var isEmpty: Bool {
        return body.isEmpty
    }

    public init(body: String, contentType: String = SIPMessageContent.plainTextContentType) {
        self.body = body
        self.contentType = contentType
    }
}
