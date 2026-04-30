// ItemType.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import Foundation

enum ItemType: String, CaseIterable {
    case healthPotion = "Health Potion"
    case shield       = "Iron Shield"
    case charm        = "Friendship Charm"

    var description: String {
        switch self {
        case .healthPotion: return "Restores 10 HP."
        case .shield:       return "Reduces damage taken by 2."
        case .charm:        return "Acts are more effective."
        }
    }
}
