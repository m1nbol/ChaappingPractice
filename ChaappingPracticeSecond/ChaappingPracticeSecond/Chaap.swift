//
//  Chaap.swift
//  ChaappingPracticeSecond
//
//  Created by BoMin Lee on 7/23/25.
//

import Foundation
import SwiftData

@Model
class Chaap {
    @Attribute(.unique) var id: UUID = UUID()
    
    /// 자동 생성
    var createdAt: Date
    var place: String?
    var latitude: Double?
    var longitude: Double?
    
    /// 사용자가 추가 가능(Optional)
    var title: String?
    var memo: String?
    var photoData: Data?
    
    /// Peer 목록
    @Relationship(deleteRule: .nullify) var peers: [Peer] = []
    
    init(createdAt: Date = Date(),
         place: String? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         title: String? = nil,
         memo: String? = nil,
         photoData: Data? = nil,
         peers: [Peer]) {
        
        self.createdAt = createdAt
        self.place = place
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.memo = memo
        self.photoData = photoData
        self.peers = peers
    }
    
    /// Chaap의 수정 가능 여부를 결정
    var isEditable: Bool {
        return Date().timeIntervalSince(createdAt) < 86400 // 24시간
    }
}
