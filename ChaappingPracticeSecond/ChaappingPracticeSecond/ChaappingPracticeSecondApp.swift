//
//  ChaappingPracticeSecondApp.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI

@main
struct ChaappingPracticeSecondApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [Chaap.self, Peer.self])
        }
    }
}
