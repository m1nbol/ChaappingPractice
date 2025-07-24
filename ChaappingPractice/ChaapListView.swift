//
//  ChaapListView.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/23/25.
//

import SwiftUI
import SwiftData

struct ChaapListView: View {
    
    @Query(sort: \Chaap.createdAt, order: .reverse) private var chaaps: [Chaap]  // 최신순 정렬

    var body: some View {
        NavigationStack {
            List {
                ForEach(chaaps) { chaap in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chaap.place ?? "위치 정보 없음")
                            .font(.headline)

                        if let lat = chaap.latitude, let lon = chaap.longitude {
                            Text(String(format: "📍 %.4f, %.4f", lat, lon))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let title = chaap.title {
                            Text("제목: \(title)")
                        }

                        if let memo = chaap.memo {
                            Text("메모: \(memo)")
                                .lineLimit(2)
                        }

                        
                        Text("🕒 \(chaap.createdAt.formatted(date: .numeric, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        
                        if !chaap.peers.isEmpty {
                            let peerNames = chaap.peers.map(\.displayName).joined(separator: ", ")
                            Text("👥 Peers: \(peerNames)")
                                .font(.footnote)
                        }
                        
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("📘 저장된 Chaap")
            .task {
                print(chaaps.count)
            }
        }
    }
}
