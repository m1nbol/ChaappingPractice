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

class ChaapManager: NSObject, ObservableObject, NISessionDelegate, MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate {
    enum DistanceDirectionState {
        case closeUpInFOV, notCloseUpInFOV, outOfFOV, unknown
    }

    @Published var state: DistanceDirectionState = .unknown
    @Published var distanceText: String = ""
    @Published var monkeyEmoji: String = ""
    @Published var infoText: String = "Searching for peers..."
    @Published var peerDisplayName: String = ""
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeer: MCPeerID?
    @Published var pendingInvitation: MCPeerID?

    private var invitationResponseHandler: ((Bool, MCSession?) -> Void)?
    private var session: NISession?
    private var peerDiscoveryToken: NIDiscoveryToken?
    private var sharedToken = false
    private var impact = UIImpactFeedbackGenerator(style: .medium)

    private let serviceType = "chaap"
    private let myPeerID: MCPeerID
    private let mcSession: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    
    private var hasPrintedLocation = false
    @Bindable private var locationManager = LocationManager.shared

    override init() {
        let name = UserDefaults.standard.string(forKey: UserDefaultsKeys.nickname) ?? UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: name)
        self.mcSession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        self.advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: [MPCSessionConstants.kKeyIdentity: "device"], serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

        super.init()

        self.session = NISession()
        self.session?.delegate = self

        self.mcSession.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self

        self.advertiser.startAdvertisingPeer()
        self.browser.startBrowsingForPeers()
    }

    func connect(to peer: MCPeerID) async {
        browser.invitePeer(peer, to: mcSession, withContext: nil, timeout: 10)
        print("✅ Connected to peer: \(peer.displayName)")
    }

    func respondToInvitation(accept: Bool) {
        invitationResponseHandler?(accept, accept ? mcSession : nil)
        pendingInvitation = nil
        invitationResponseHandler = nil
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
//                self.connectedPeer = peerID
//                self.peerDisplayName = peerID.displayName
//                self.infoText = "Connected to \(peerID.displayName)"
//                if let token = self.session?.discoveryToken, !self.sharedToken {
//                    self.sendToken(token)
//                    self.sharedToken = true
//                }
//                
                self.connectedPeer = peerID
                self.peerDisplayName = peerID.displayName
                self.infoText = "Connected to \(peerID.displayName)"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let token = self.session?.discoveryToken, !self.sharedToken {
                        self.sendToken(token)
                        self.sharedToken = true
                    }
                }
            case .notConnected:
                self.connectedPeer = nil
                self.infoText = "Disconnected"
                self.state = .unknown
                self.sharedToken = false
            case .connecting:
                self.infoText = "Connecting..."
            @unknown default: break
            }
        }
    }

//    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
//        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { return }
//        peerDiscoveryToken = token
//        let config = NINearbyPeerConfiguration(peerToken: token)
//        self.session?.run(config)
//    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("📦 token 수신 from \(peerID.displayName)")

        guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            print("❌ 토큰 디코딩 실패")
            return
        }

        peerDiscoveryToken = token
        let config = NINearbyPeerConfiguration(peerToken: token)
        self.session?.run(config)
        print("✅ NI session run 시작됨 with token: \(token)")
    }
    
    func sendToken(_ token: NIDiscoveryToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        try? mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if !discoveredPeers.contains(peerID) {
            DispatchQueue.main.async {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.pendingInvitation = peerID
            self.invitationResponseHandler = invitationHandler
        }
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerToken = peerDiscoveryToken,
              let obj = nearbyObjects.first(where: { $0.discoveryToken == peerToken }) else { return }
        updateState(from: obj)
    }

    func updateState(from obj: NINearbyObject) {
        Task {
            let isClose = obj.distance.map { $0 < 0.5 } ?? false
            let isVeryClose = obj.distance.map { $0 < 0.3 } ?? false
            
            await MainActor.run {
                if let d = obj.distance {
                    self.distanceText = String(format: "%.2f m", d)
                }
                if isClose {
                    self.state = .closeUpInFOV
                    self.monkeyEmoji = "👐"
                } else {
                    self.state = .notCloseUpInFOV
                    self.monkeyEmoji = "🥹"
                }
            }
            
            if isVeryClose && !self.hasPrintedLocation {
                self.hasPrintedLocation = true
                await self.locationManager.printCurrentLocation()
            }
            if isClose {
                await self.impact.impactOccurred()
            }
        }
            
//        let isClose = obj.distance.map { $0 < 0.5 } ?? false
//        let isVeryClose = obj.distance.map { $0 < 0.3 } ?? false
//        
//        Task {
//            if let d = obj.distance {
//                self.distanceText = String(format: "%.2f m", d)
//            }
//            
//            if isVeryClose && !self.hasPrintedLocation {
//                self.hasPrintedLocation = true
//                await self.locationManager.printCurrentLocation()
//            }
//            
//            if isClose {
//                self.state = .closeUpInFOV
//                self.monkeyEmoji = "👐"
//                await self.impact.impactOccurred()
//            } else {
//                self.state = .notCloseUpInFOV
//                self.monkeyEmoji = "🥹"
//            }
//        }
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        state = .unknown
        infoText = reason == .peerEnded ? "Peer ended" : "Timeout"
    }

    func sessionWasSuspended(_ session: NISession) {
        state = .unknown
        infoText = "Suspended"
    }

    func sessionSuspensionEnded(_ session: NISession) {
        if let config = session.configuration {
            session.run(config)
            print("✅ NI session run 시작됨")
        }
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        state = .unknown
        infoText = "Invalidated: \(error.localizedDescription)"
    }
}

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
