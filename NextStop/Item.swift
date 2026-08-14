//
//  Item.swift
//  NextStop
//
//  Created by Alex Kung on 2026/7/25.
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
