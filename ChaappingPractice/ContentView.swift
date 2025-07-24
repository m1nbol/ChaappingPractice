//
//  ContentView.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/14/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State var manager = ChaapManager()
    @State var viewModel: ChaapViewModel?
    @State private var showInviteAlert = false
    @State private var showChaapListView = false
    
    var body: some View {
        VStack(spacing: 20) {
            if manager.connectedPeer == nil {
                Text("Discovered Peers")
                    .font(.headline)
                List(manager.discoveredPeers, id: \.displayName) { peer in
                    Button(peer.displayName) {
                        Task {
                            await manager.connect(to: peer)
                        }
                    }
                }
            } else {
                Text(manager.monkeyEmoji)
                    .font(.system(size: 80))
                Text("Peer: \(manager.peerDisplayName)")
                Text("Distance: \(manager.distanceText)")
                
//                Button("연결 해제") {
//                    manager.disconnect()
//                }
//                .foregroundColor(.red)
            }
            
            Button {
                showChaapListView = true
            } label: {
                Label("저장된 Chaap 보기", systemImage: "book")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
            .padding(.top, 40)
        }
        .sheet(isPresented: $showChaapListView) {
            ChaapListView()
                .modelContext(modelContext)
        }
        .task {
            viewModel = ChaapViewModel(manager: manager, modelContext: modelContext)
        }
        .padding()
        .onChange(of: manager.pendingInvitation) {
            showInviteAlert = manager.pendingInvitation != nil
        }
        .alert("연결 요청", isPresented: $showInviteAlert) {
            Button("수락") {
                manager.respondToInvitation(accept: true)
            }
            Button("거절", role: .cancel) {
                manager.respondToInvitation(accept: false)
            }
        } message: {
            Text("\(manager.pendingInvitation?.displayName ?? "") 님이 연결을 요청했습니다.")
        }
    }
}

#Preview {
    ContentView()
}
