//
//  DisplayNameView.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI

struct DisplayNameView: View {
    @AppStorage("displayName") private var displayName: String = UIDevice.current.name
    @State private var inputName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("표시 이름")) {
                    TextField("이름 입력", text: $inputName)
                }
            }
            .navigationTitle("내 이름 설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if !inputName.isEmpty {
                            displayName = inputName
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            inputName = displayName
        }
    }
}
