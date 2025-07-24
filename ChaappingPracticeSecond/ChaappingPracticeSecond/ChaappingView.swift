//
//  ChaappingView.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI
import SwiftData


struct ChaappingView: View {
    @State private var showChaapList = false
    @State private var showPeerList = false
    
    @State private var showInvitationAlert = false
    
    @State private var showDisplayNameEditor = false
    @State private var viewModel: ChaappingViewModel

    init(modelContext: ModelContext) {
        _viewModel = State(initialValue: ChaappingViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Button("내 이름 설정") {
                    showDisplayNameEditor = true
                }
                
                Button("주변 피어 선택") {
                    viewModel.startMPC()
                    showPeerList = true
                }
                
                Text("👀 Peer 연결 상태: \(viewModel.connectedPeer?.displayName ?? "없음")")
                Text("📏 거리: \(viewModel.distance?.formatted() ?? "없음") m")

                Button("📝 저장된 Chaap 보기") {
                    showChaapList = true
                }
                .sheet(isPresented: $showPeerList) {
                    if let mpcManager = viewModel.mpcManager {
                        PeerListView(mpcManager: mpcManager)
                    } else {
                        VStack {
                            Text("UNAVAILABLE")
                            Spacer()
                        }
                    }
                }
                .sheet(isPresented: $showDisplayNameEditor) {
                    DisplayNameView()
                }
                .sheet(isPresented: $showChaapList) {
                    ChaapListView()
                        .modelContext(viewModel.modelContext)
                }
                .onChange(of: viewModel.mpcManager?.pendingInvitation?.peerID) { oldValue, newValue in
                    if newValue != nil {
                        showInvitationAlert = true
                    }
                }
                .alert("초대 수신", isPresented: $showInvitationAlert) {
                    Button("수락") {
                        viewModel.acceptInvitation()
                    }
                    Button("거절", role: .cancel) {
                        viewModel.rejectInvitation()
                    }
                } message: {
                    if let peerName = viewModel.mpcManager?.pendingInvitation?.peerID.displayName {
                        Text("\(peerName) 님의 연결 요청을 수락하시겠습니까?")
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.startMPC()
        }
    }
}

extension DistanceState {
    var description: String {
        switch self {
        case .closeUpinFOV: return "아주 가까움"
        case .notCloseUpInFOV: return "조금 가까움"
        case .outOfFOV: return "범위 밖"
        case .unknown: return "모름"
        }
    }
}
