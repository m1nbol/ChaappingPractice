//
//  ContentView.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    var body: some View {
        ChaappingView(modelContext: modelContext)
    }
}

#Preview {
    ContentView()
}
