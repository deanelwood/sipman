//
//  SoftphoneRegistrationState.swift
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

enum SoftphoneRegistrationState: Equatable {
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
}
