//
//  ChaapViewModel.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/22/25.
//

import Foundation
import Observation
import SwiftData
import MultipeerConnectivity

@Observable
final class ChaapViewModel {
    // MARK: - Dependencies
    let manager: ChaapManager
    let modelContext: ModelContext
    private let locationManager = LocationManager.shared

    // MARK: - Init
    init(manager: ChaapManager, modelContext: ModelContext) {
        self.manager = manager
        self.modelContext = modelContext
        setupManagerCallback()
    }

    // MARK: - 콜백 연결
    private func setupManagerCallback() {
        manager.onCloseDetected = { [weak self] peer in
            Task {
                await self?.createChaap(peerDisplayName: peer.displayName)
            }
        }
    }

    // MARK: - Chaap 생성
    func createChaap(peerDisplayName: String) async {
        guard let location = locationManager.currentLocation else {
            print("❌ 현재 위치 없음")
            return
        }

        // 주소 업데이트 (currentAddress 내부적으로 저장됨)
        await locationManager.reverseGeocode(location: location)

        let peer = Peer(displayName: peerDisplayName)
        let chaap = Chaap(
            createdAt: Date(),
            place: locationManager.currentAddress,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            title: nil,
            memo: nil,
            photoData: nil,
            peers: [peer]
        )

        do {
            modelContext.insert(chaap)
            try modelContext.save()
            print("✅ Chaap 저장 완료")
            
            manager.endSession()
        } catch {
            print("❌ Chaap 저장 실패: \(error.localizedDescription)")
        }
    }
}

//@Observable
//class ChaapViewModel {
//    private let manager: ChaapManager
//    private let locationManager = LocationManager.shared
//    private let modelContext: ModelContext
//    
//    init(manager: ChaapManager, modelContext: ModelContext) {
//        self.manager = manager
//        self.modelContext = modelContext
//        observeClose()
//    }
//    
//    private let observeClose() {
//        Task {
//            for wait close in manager.$isClose {
//                if close, let peer = manager.connectedPeer {
//                    await createChaap(peerDisplayName: peer.displayName)
//                }
//            }
//        }
//    }
//    
//    func createChaap(peerDisplayName: String) async {
//        guard let location = locationManager.currentLocation else {
//            print("❌ 장소 없음")
//            return
//        }
//        
//        await locationManager.reverseGeocode(location: location)
//        
//        let peer = Peer(displayName: peerDisplayName)
//        let chaap = Chaap(
//            createdAt: Date(),
//            place: locationManager.currentAddress,
//            latitude: location.coordinate.latitude,
//            longitude: location.coordinate.longitude,
//            title: nil,
//            memo: nil,
//            photoData: nil,
//            peers: [peer]
//        )
//        
//        do {
//            modelContext.insert(chaap)
//            try modelContext.save()
//            print("챱 저장 완료")
//        } catch {
//            print("챱 저장 실패: \(error)")
//        }
//    }
//}

//@Observable
//class ChaapViewModel {
//    let locationManager = LocationManager.shared
//    let modelContext: ModelContext
//    
//    init(modelContext: ModelContext) {
//        self.modelContext = modelContext
//    }
//    
//    func createChaap(peerDisplayName: String) async {
//        /// 위치 정보(CLLocation)도 우선 가져옴 -> 추후 지도에 띄우려면 필요
//        guard let location = locationManager.currentLocation else { return }
//        
//        /// 역지오코딩 수행(주소 문자열 업데이트 위함)
//        await locationManager.reverseGeocode(location: location)
//        
//        /// Peer 모델 생성
//        let peer = Peer(displayName: peerDisplayName)
//        
//        /// Chaap 인스턴스 생성
//        let chaap = Chaap(
//            createdAt: Date(),
//            place: locationManager.currentAddress,
//            latitude: location.coordinate.latitude,
//            longitude: location.coordinate.longitude,
//            title: nil,
//            description: nil,
//            photoData: nil,
//            peers: [peer]
//        )
//        
//        do {
//            modelContext.insert(chaap)
//            try modelContext.save()
//            print("Chaap 저장 완료! :\(chaap)")
//            print("-------------------------")
//        } catch {
//            print("Chaap 저장 실패: \(error.localizedDescription)")
//        }
//    }
//}
