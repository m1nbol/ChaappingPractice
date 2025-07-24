//
//  Peer.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/21/25.
//

import Foundation
import SwiftData

@Model
class Peer {
    @Attribute(.unique) var id: UUID = UUID()
    var displayName: String
    
    init(displayName: String) {
        self.displayName = displayName
    }
}
