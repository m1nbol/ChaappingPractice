//
//  MCSessionState.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import Foundation
import MultipeerConnectivity

extension MCSessionState {
    var displayString: String {
        switch self {
        case .notConnected:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        @unknown default:
            return "Unknown"
        }
    }
}
