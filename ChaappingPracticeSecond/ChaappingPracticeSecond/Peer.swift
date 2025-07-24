//
//  Peer.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import Foundation
import SwiftData
import NearbyInteraction

@Model
class Peer {
    @Attribute(.unique)
    var tokenString: String

    var displayName: String

    init(token: NIDiscoveryToken, displayName: String) {
        self.tokenString = Peer.tokenToString(token)
        self.displayName = displayName
    }

    /// 토큰 -> 고유 식별자
    static func tokenToString(_ token: NIDiscoveryToken) -> String {
        return token.description
    }
}
