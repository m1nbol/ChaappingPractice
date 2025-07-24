//
//  Chaap.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/21/25.
//

import Foundation
import SwiftData

@Model
class Chaap {
    @Attribute(.unique) var id: UUID = UUID()
    
    var createdAt: Date
    var place: String?
    var latitude: Double?
    var longitude: Double?
    
    var title: String?
    var memo: String?
    var photoData: Data?
    
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
