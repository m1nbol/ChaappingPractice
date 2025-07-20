//
//  ContentView.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/14/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var manager = ChaapManager()
    @State private var showInviteAlert = false
    
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
        }
        .padding()
        .animation(.easeInOut, value: manager.state)
        .onChange(of: manager.pendingInvitation) { peer in
            showInviteAlert = peer != nil
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
