//
//  WatchSessionManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation
import WatchConnectivity

class WatchSessionManager {
    // Notifications
//    enum Notifications : String {
//        case DidReceiveWatchCommand = "didReceiveWatchCommand"
//    }

    // Constants
    enum Mode: String {
        case Inactive = "MainInterfaceController"
        case Scan = "ScanningInterfaceController"
        case Connected = "ConnectedInterfaceController"
        case Controller = "ControlModeInterfaceController"
    }
    
    
    // Singleton
    static let sharedInstance = WatchSessionManager()

    // Data
    var session: WCSession?
    
    //
    func activateWithDelegate(delegate: WCSessionDelegate?) {
        if(WCSession.isSupported()){
            DLog(message: "watchSession setup")
            session = WCSession.default
            session!.delegate = delegate
            session!.activate()
        }
    }
    
    // MARK: - iOS Specific
#if os(iOS)
    func updateApplicationContext(mode: Mode) {
      guard let session = WatchSessionManager.sharedInstance.session, session.isPaired && session.isWatchAppInstalled else {
            return
        }
    
        if #available(iOS 9.3, *) {
          guard session.activationState == .activated else {
                return
            }
        }
    
        do {
            let bleFoundPeripherals = BleManager.sharedInstance.blePeripheralsCount()
  var appContext: [String: AnyObject] = ["mode": mode.rawValue as AnyObject, "bleFoundPeripherals": bleFoundPeripherals as AnyObject]
            
            if let bleConnectedPeripheral = BleManager.sharedInstance.blePeripheralConnected {
              appContext["bleConnectedPeripheralName"] = bleConnectedPeripheral.name as AnyObject
              appContext["bleHasUart"] = bleConnectedPeripheral.isUartAdvertised() as AnyObject
            }
            try session.updateApplicationContext(appContext)
        }
        catch {
            //DLog("updateApplicationContext error")
        }
    }
#endif
}

extension Notification.Name {
    static let wsmDidReceiveWatchCommand = Notification.Name("didReceiveWatchCommand")
}
