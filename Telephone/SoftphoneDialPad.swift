//
//  SoftphoneDialPad.swift
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

struct SoftphoneDialPad: Equatable {
    private(set) var destination = ""

    var canCall: Bool {
        return !destination.isEmpty
    }

    mutating func append(_ value: String) {
        destination.append(value)
    }

    mutating func deleteLast() {
        guard !destination.isEmpty else { return }
        destination.removeLast()
    }

    mutating func clear() {
        destination.removeAll()
    }
}

enum SoftphoneKeypadKeyboardAction: Equatable {
    case append(String)
    case deleteLast
    case clear
    case submit

    init?(characters: String?, keyCode: UInt16) {
        switch keyCode {
        case 36, 76:
            self = .submit
        case 51, 117:
            self = .deleteLast
        case 53:
            self = .clear
        default:
            guard let characters, characters.count == 1, let character = characters.first else {
                return nil
            }
            let value = String(character)
            guard Self.acceptedCharacters.contains(character) else {
                return nil
            }
            self = .append(value)
        }
    }

    private static let acceptedCharacters = Set("0123456789*#+")
}
