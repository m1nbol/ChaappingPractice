//
//  NicknameView.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/15/25.
//

import SwiftUI

struct NicknameView: View {
    @AppStorage(UserDefaultsKeys.nickname) private var nickname: String = ""
    @State private var tempName: String = ""

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("닉네임을 입력해주세요")
                .font(.title2)
            TextField("예: 민수", text: $tempName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button("확인") {
                if !tempName.isEmpty {
                    nickname = tempName
                    onComplete()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
