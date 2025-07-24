//
//  PeerListView.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI
import MultipeerConnectivity

struct PeerListView: View {
    @Environment(\.dismiss) private var dismiss
    var mpcManager: MultipeerConnectivityManager
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(mpcManager.nearbyPeers, id: \.self) { peer in
                    Button {
                        mpcManager.invite(peer)
                        dismiss()
                    } label: {
                        HStack {
                            Text(peer.displayName)
                            Spacer()
                            Image(systemName: "paperplane.fill")
                        }
                    }
                }
            }
            .navigationTitle("주변 Peer 선택")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}
