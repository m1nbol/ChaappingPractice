//
//  ChaappingPracticeApp.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/14/25.
//

import SwiftUI
import MultipeerConnectivity
import NearbyInteraction

@main
struct NearbyPeerApp: App {
    @AppStorage(UserDefaultsKeys.nickname) private var nickname: String = ""

    var body: some Scene {
        WindowGroup {
            if nickname.isEmpty {
                NicknameView {
                    print("닉넴 완료")
                }
            } else {
                ContentView()
            }
        }
    }
}
