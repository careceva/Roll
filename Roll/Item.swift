//
//  Item.swift
//  Roll
//
//  Created by Catalin Sandru on 19.03.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
