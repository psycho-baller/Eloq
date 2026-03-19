//
//  Item.swift
//  Eloq
//
//  Created by Rami Maalouf on 2026-03-20.
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
