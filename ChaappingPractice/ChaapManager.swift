//
//  ChaapManager.swift
//  ChaappingPractice
//
//  Created by BoMin Lee on 7/14/25.
//

import Foundation
import MultipeerConnectivity
import NearbyInteraction
import Observation
import SwiftUI

/// Nearby Interaction + Multipeer Connectivity를 모두 관리하는 Manager입니다.
@Observable
final class ChaapManager: NSObject {
    // MARK: - Published 상태
    var connectionState: ConnectionState = .notConnected
    var distanceText: String = ""
    var monkeyEmoji: String = "🤷"
    var peerDisplayName: String = ""
    var discoveredPeers: [MCPeerID] = []
    var connectedPeer: MCPeerID?
    var pendingInvitation: MCPeerID?
    var isClose: Bool = false
    var onCloseDetected: ((MCPeerID) -> Void)?
    var didCreateChaap = false

    // MARK: - 내부 구성
    private let serviceType = "chaap"
    private let myPeerID: MCPeerID
    private let mcSession: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let niSession = NISession()

    private var peerDiscoveryToken: NIDiscoveryToken?
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private var sharedToken = false

    // MARK: - Init
    override init() {
        let name = UserDefaults.standard.string(forKey: UserDefaultsKeys.nickname) ?? UIDevice.current.name
        myPeerID = MCPeerID(displayName: name)
        mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

        super.init()

        niSession.delegate = self
        mcSession.delegate = self
        advertiser?.delegate = self
        browser?.delegate = self

        start()
    }
    
    func start() {
        print("MPC 실행")
        
        if advertiser == nil {
            print("start() - advertiser 재초기화")
            advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
            advertiser?.delegate = self
        }
        
        advertiser?.startAdvertisingPeer()
        
        if browser == nil {
            print("start() - browser 재초기화")
            browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
            browser?.delegate = self
        }
        browser?.startBrowsingForPeers()
    }

    // MARK: - Peer 연결
    func connect(to peer: MCPeerID) {
        browser?.invitePeer(peer, to: mcSession, withContext: nil, timeout: 10)
    }

    func respondToInvitation(accept: Bool) {
        invitationHandler?(accept, accept ? mcSession : nil)
        invitationHandler = nil
        pendingInvitation = nil
    }

    private func sendDiscoveryToken(_ token: NIDiscoveryToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
    }

    private func updateState(from object: NINearbyObject) {
        Task {
            let close = object.distance.map { $0 < 0.3 } ?? false

            await MainActor.run {
                if let d = object.distance {
                    self.distanceText = String(format: "%.2f m", d)
                }
                self.isClose = close
                self.monkeyEmoji = close ? "🍎" : "🥹"
            }

            if close, !didCreateChaap {
                await self.impact.impactOccurred()
                didCreateChaap = true
                if let peer = connectedPeer {
                    onCloseDetected?(peer)
                }
            }
        }
    }
}

extension ChaapManager: MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, NISessionDelegate {
    // MARK: - NI Delegate
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let token = peerDiscoveryToken,
              let object = nearbyObjects.first(where: { $0.discoveryToken == token }) else { return }
        updateState(from: object)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        connectionState = .notConnected
    }

    // MARK: - MCSession Delegate
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connectedPeer = peerID
                self.peerDisplayName = peerID.displayName
                self.connectionState = .connected

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let token = self.niSession.discoveryToken, !self.sharedToken {
                        self.sendDiscoveryToken(token)
                        self.sharedToken = true
                    }
                }

            case .connecting:
                self.connectionState = .connecting

            case .notConnected:
                self.connectionState = .notConnected
                self.connectedPeer = nil
                self.sharedToken = false

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { return }
        peerDiscoveryToken = token
        niSession.run(NINearbyPeerConfiguration(peerToken: token))
    }

    // 생략 가능한 delegate들
    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}

    // MARK: - MCNearbyServiceBrowser
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo _: [String: String]?) {
        if !discoveredPeers.contains(peerID) {
            discoveredPeers.append(peerID)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        discoveredPeers.removeAll { $0 == peerID }
    }

    // MARK: - Advertiser
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext _: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        self.pendingInvitation = peerID
        self.invitationHandler = invitationHandler
    }
    
    
    /// MPC adverting & browsing 중단 MCSession 해제
    func invalidate() {
        print("MultipeerManager - invalidate()")
        // 1. 먼저 안전하게 중지
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        
        // 2. mcSession 연결 해제
        mcSession.disconnect()
        mcSession.delegate = nil
        
        // 3. delegate 해제
        advertiser?.delegate = nil
        browser?.delegate = nil
        
        // 4. 객체 제거
        advertiser = nil
        browser = nil
    }

    /// NISession 해제
    /// MPC advertising, browsing 중단 MCSession 해제
    func endSession() {
        // 1. NearbyInteraction 세션 종료
        niSession.invalidate()

        // 2. Advertiser, Browser 중지
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        
        // 3. mcSession 해제
        mcSession.disconnect()
        mcSession.delegate = nil
        
        // 4. delegate 해제
        advertiser?.delegate = nil
        browser?.delegate = nil
        
        // 5. 객체 제거
        advertiser = nil
        browser = nil

        // 연결 상태 리셋
        connectionState = .notConnected
        connectedPeer = nil
        peerDiscoveryToken = nil
        sharedToken = false

        print("🛑 세션 종료 완료")
    }
}



//class ChaapManager: NSObject, ObservableObject, NISessionDelegate, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
//    enum DistanceDirectionState {
//        case closeUpInFOV, notCloseUpInFOV, outOfFOV, unknown
//    }
//
//    var chaapViewModel: ChaapViewModel?
//    
//    @Published var state: DistanceDirectionState = .unknown
//    @Published var distanceText: String = ""
//    @Published var monkeyEmoji: String = ""
//    @Published var infoText: String = "Searching for peers..."
//    @Published var peerDisplayName: String = ""
//    @Published var discoveredPeers: [MCPeerID] = []
//    @Published var connectedPeer: MCPeerID?
//    @Published var pendingInvitation: MCPeerID?
//
//    private var invitationResponseHandler: ((Bool, MCSession?) -> Void)?
//    private var session: NISession?
//    private var peerDiscoveryToken: NIDiscoveryToken?
//    private var sharedToken = false
//    private var impact = UIImpactFeedbackGenerator(style: .medium)
//
//    private let serviceType = "chaap"
//    private let myPeerID: MCPeerID
//    private let mcSession: MCSession
//    private let advertiser: MCNearbyServiceAdvertiser
//    private let browser: MCNearbyServiceBrowser
//    
//    private var hasPrintedLocation = false
//    @Bindable private var locationManager = LocationManager.shared
//
//    override init() {
//        let name = UserDefaults.standard.string(forKey: UserDefaultsKeys.nickname) ?? UIDevice.current.name
//        self.myPeerID = MCPeerID(displayName: name)
//        self.mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
//        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: [MPCSessionConstants.kKeyIdentity: "device"], serviceType: serviceType)
//        self.browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
//
//        super.init()
//
//        self.session = NISession()
//        self.session?.delegate = self
//
//        self.mcSession.delegate = self
//        self.advertiser.delegate = self
//        self.browser.delegate = self
//
//        self.advertiser.startAdvertisingPeer()
//        self.browser.startBrowsingForPeers()
//    }
//
//    func connect(to peer: MCPeerID) async {
//        browser.invitePeer(peer, to: mcSession, withContext: nil, timeout: 10)
//        print("✅ Connected to peer: \(peer.displayName)")
//    }
//
//    func respondToInvitation(accept: Bool) {
//        invitationResponseHandler?(accept, accept ? mcSession : nil)
//        pendingInvitation = nil
//        invitationResponseHandler = nil
//    }
//
//    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
//        DispatchQueue.main.async {
//            switch state {
//            case .connected:
////                self.connectedPeer = peerID
////                self.peerDisplayName = peerID.displayName
////                self.infoText = "Connected to \(peerID.displayName)"
////                if let token = self.session?.discoveryToken, !self.sharedToken {
////                    self.sendToken(token)
////                    self.sharedToken = true
////                }
////                
//                self.connectedPeer = peerID
//                self.peerDisplayName = peerID.displayName
//                self.infoText = "Connected to \(peerID.displayName)"
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    if let token = self.session?.discoveryToken, !self.sharedToken {
//                        self.sendToken(token)
//                        self.sharedToken = true
//                    }
//                }
//            case .notConnected:
//                self.connectedPeer = nil
//                self.infoText = "Disconnected"
//                self.state = .unknown
//                self.sharedToken = false
//            case .connecting:
//                self.infoText = "Connecting..."
//            @unknown default: break
//            }
//        }
//    }
//
////    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
////        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { return }
////        peerDiscoveryToken = token
////        let config = NINearbyPeerConfiguration(peerToken: token)
////        self.session?.run(config)
////    }
//
//    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        print("📦 token 수신 from \(peerID.displayName)")
//
//        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
//            print("❌ 토큰 디코딩 실패")
//            return
//        }
//
//        peerDiscoveryToken = token
//        let config = NINearbyPeerConfiguration(peerToken: token)
//        self.session?.run(config)
//        print("✅ NI session run 시작됨 with token: \(token)")
//    }
//    
//    func sendToken(_ token: NIDiscoveryToken) {
//        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
//        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
//    }
//
//    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
//    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
//    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
//
//    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
//        if !discoveredPeers.contains(peerID) {
//            DispatchQueue.main.async {
//                self.discoveredPeers.append(peerID)
//            }
//        }
//    }
//
//    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
//        DispatchQueue.main.async {
//            self.discoveredPeers.removeAll { $0 == peerID }
//        }
//    }
//
//    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
//        DispatchQueue.main.async {
//            self.pendingInvitation = peerID
//            self.invitationResponseHandler = invitationHandler
//        }
//    }
//
//    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
//        guard let peerToken = peerDiscoveryToken,
//              let obj = nearbyObjects.first(where: { $0.discoveryToken == peerToken }) else { return }
//        updateState(from: obj)
//    }
//
//    func updateState(from obj: NINearbyObject) {
//        Task {
//            let isClose = obj.distance.map { $0 < 0.5 } ?? false
//            let isVeryClose = obj.distance.map { $0 < 0.3 } ?? false
//            
//            await MainActor.run {
//                if let d = obj.distance {
//                    self.distanceText = String(format: "%.2f m", d)
//                }
//                if isClose {
//                    self.state = .closeUpInFOV
//                    self.monkeyEmoji = "👐"
//                } else {
//                    self.state = .notCloseUpInFOV
//                    self.monkeyEmoji = "🥹"
//                }
//            }
//            
//            if isVeryClose {
//                await chaapViewModel?.createChaap(peerDisplayName: connectedPeer.displayName)
//            }
//            if isClose {
//                await self.impact.impactOccurred()
//            }
//        }
//            
////        let isClose = obj.distance.map { $0 < 0.5 } ?? false
////        let isVeryClose = obj.distance.map { $0 < 0.3 } ?? false
////        
////        Task {
////            if let d = obj.distance {
////                self.distanceText = String(format: "%.2f m", d)
////            }
////            
////            if isVeryClose && !self.hasPrintedLocation {
////                self.hasPrintedLocation = true
////                await self.locationManager.printCurrentLocation()
////            }
////            
////            if isClose {
////                self.state = .closeUpInFOV
////                self.monkeyEmoji = "👐"
////                await self.impact.impactOccurred()
////            } else {
////                self.state = .notCloseUpInFOV
////                self.monkeyEmoji = "🥹"
////            }
////        }
//    }
//
//    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
//        state = .unknown
//        infoText = reason == .peerEnded ? "Peer ended" : "Timeout"
//    }
//
//    func sessionWasSuspended(_ session: NISession) {
//        state = .unknown
//        infoText = "Suspended"
//    }
//
//    func sessionSuspensionEnded(_ session: NISession) {
//        if let config = session.configuration {
//            session.run(config)
//            print("✅ NI session run 시작됨")
//        }
//    }
//
//    func session(_ session: NISession, didInvalidateWith error: Error) {
//        state = .unknown
//        infoText = "Invalidated: \(error.localizedDescription)"
//    }
//}

//@Observable
//class ChaapManager: NSObject {
//    static let shared = ChaapManager()
//    
//    private var locationManager = LocationManager()
//    
//    //MARK: - Multipeer Connectivity
//    private var myPeerID: MCPeerID!
//    private var mcSession: MCSession!
//    private var advertiser: MCNearbyServiceAdvertiser!
//    private var browser: MCNearbyServiceBrowser!
//    
//    @Published var discoveredPeers: [MCPeerID] = []
//    @Published var connectedPeer: MCPeerID?
//    @Published var showInvitationPrompt = false
//    @Published var invitedPeer: MCPeerID?
//    
//    //MARK: - Nearby Interaction
//    private var niSession: NISession?
//    @Published var currentDistance: Float?
//    
//    override init() {
//        super.init()
//        
//        let savedDisplayName = UserDefaults.standard.string(forKey: "peerDisplayName") ?? UIDevice.current.name
//        myPeerID = MCPeerID(displayName: savedDisplayName)
//        mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
//        mcSession.delegate = self
//        
//        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "chaap")
//        advertiser.delegate = self
//        advertiser.startAdvertisingPeer()
//        
//        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "chaap")
//        browser.delegate = self
//        browser.startBrowsingForPeers()
//    }
//    
//    func invite(_ peer: MCPeerID) {
//        invitedPeer = peer
//        browser.invitePeer(peer, to: mcSession, withContext: nil, timeout: 10)
//    }
//    
//    func startNearbySession(with token: NIDiscoveryToken) {
//        niSession = NISession()
//        niSession?.delegate = self
//        let config = NINearbyPeerConfiguration(peerToken: token)
//        niSession?.run(config)
//    }
//}
//
//extension ChaapManager: MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
//    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
//        if !discoveredPeers.contains(peerID) && peerID != myPeerID {
//            discoveredPeers.append(peerID)
//        }
//    }
//    
//    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
//        discoveredPeers.removeAll { $0 == peerID }
//    }
//    
//    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
//        showInvitationPrompt = true
//        Task { @MainActor in
//            let accept = await self.promptUserForInvitation(from: peerID)
//            invitationHandler(accept, self.mcSession)
//        }
//    }
//    
//    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
//        switch state {
//        case .connected:
//            connectedPeer = peerID
//            if let token = niSession?.discoveryToken,
//               let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
//                try? session.send(data, toPeers: [peerID], with: .reliable)
//            }
//        default:
//            break
//        }
//    }
//    
//    /// Unused delegate methods
//    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        if let peerToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
//            startNearbySession(with: peerToken)
//        }
//    }
//    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) { }
//    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) { }
//    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) { }
//    
//    /// Invitation Prompt
//    func promptUserForInvitation(from peer: MCPeerID) async -> Bool {
//        try? await Task.sleep(nanoseconds: 1_000_000_000)
//        return true
//    }
//    
//    
//}
//
//extension ChaapManager: NISessionDelegate {
//    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
//        guard let object = nearbyObjects.first else { return }
//        currentDistance = object.distance
//        
//        if let distance = currentDistance, distance < 0.3 {
//            //MARK: Location Manager 기능 수행
//            locationManager.printCurrentLocation()
//        }
//    }
//    
//    func sessionWasSuspended(_ session: NISession) { }
//    func sessionSuspensionEnded(_ session: NISession) { }
//    func session(_ session: NISession, didInvalidateWith error: any Error) { }
//}
