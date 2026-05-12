//
//  SoftphoneDialPad.swift
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

import Foundation
import UseCases

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

struct SoftphoneKeypadKey: Equatable, Identifiable {
    let value: String
    let letters: String
    let longPressValue: String?

    var id: String { value }

    static let dialingKeys = [
        SoftphoneKeypadKey(value: "1", letters: "", longPressValue: nil),
        SoftphoneKeypadKey(value: "2", letters: "ABC", longPressValue: nil),
        SoftphoneKeypadKey(value: "3", letters: "DEF", longPressValue: nil),
        SoftphoneKeypadKey(value: "4", letters: "GHI", longPressValue: nil),
        SoftphoneKeypadKey(value: "5", letters: "JKL", longPressValue: nil),
        SoftphoneKeypadKey(value: "6", letters: "MNO", longPressValue: nil),
        SoftphoneKeypadKey(value: "7", letters: "PQRS", longPressValue: nil),
        SoftphoneKeypadKey(value: "8", letters: "TUV", longPressValue: nil),
        SoftphoneKeypadKey(value: "9", letters: "WXYZ", longPressValue: nil),
        SoftphoneKeypadKey(value: "*", letters: "", longPressValue: nil),
        SoftphoneKeypadKey(value: "0", letters: "+", longPressValue: "+"),
        SoftphoneKeypadKey(value: "#", letters: "", longPressValue: nil)
    ]
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

struct SoftphoneCallingContactRowModel: Equatable, Identifiable {
    let id: String
    let name: String
    let label: String
    let number: String
    let displayNumber: String

    var favouriteIDs: Set<String> {
        [id, Self.id(name: name, label: label, number: displayNumber)]
    }

    static func id(name: String, label: String, number: String) -> String {
        "\(name)|\(label)|\(number)"
    }
}

struct SoftphoneCallingContactsModel: Equatable {
    let rows: [SoftphoneCallingContactRowModel]

    init(contacts: [Contact]) {
        rows = contacts.flatMap(Self.rows).sorted {
            let nameComparison = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameComparison != .orderedSame {
                return nameComparison == .orderedAscending
            }
            return $0.displayNumber.localizedCaseInsensitiveCompare($1.displayNumber) == .orderedAscending
        }
    }

    func rows(matching query: String) -> [SoftphoneCallingContactRowModel] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return rows }
        return rows.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.label.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.number.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.displayNumber.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func rows(withIDs ids: Set<String>, matching query: String) -> [SoftphoneCallingContactRowModel] {
        rows(matching: query).filter { !ids.isDisjoint(with: $0.favouriteIDs) }
    }

    private static func rows(for contact: Contact) -> [SoftphoneCallingContactRowModel] {
        contact.phones.compactMap { phone in
            let number = phone.number.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !number.isEmpty else { return nil }
            let displayNumber = number.ak_prettyFormattedPhoneNumber
            let name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = name.isEmpty ? displayNumber : name
            let displayLabel = phone.label.isEmpty ? "phone" : phone.label
            return SoftphoneCallingContactRowModel(
                id: SoftphoneCallingContactRowModel.id(name: displayName, label: displayLabel, number: number),
                name: displayName,
                label: displayLabel,
                number: number,
                displayNumber: displayNumber
            )
        }
    }
}

struct SoftphoneContactFavourites: Equatable {
    static let storageKey = "SIPManCallingFavouriteContactRowIDs"

    private(set) var ids: Set<String>

    init(ids: Set<String> = []) {
        self.ids = ids
    }

    init(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decodedIDs = try? JSONDecoder().decode([String].self, from: data) else {
            ids = []
            return
        }
        ids = Set(decodedIDs)
    }

    var rawValue: String {
        guard !ids.isEmpty,
              let data = try? JSONEncoder().encode(ids.sorted()),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    func contains(_ row: SoftphoneCallingContactRowModel) -> Bool {
        !ids.isDisjoint(with: row.favouriteIDs)
    }

    func contains(id: String) -> Bool {
        ids.contains(id)
    }

    mutating func toggle(_ row: SoftphoneCallingContactRowModel) {
        if contains(row) {
            row.favouriteIDs.forEach { ids.remove($0) }
        } else {
            ids.insert(row.id)
        }
    }

    mutating func toggle(id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }
}
