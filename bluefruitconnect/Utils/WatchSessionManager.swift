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
    enum Notifications : String {
        case DidReceiveWatchCommand = "didReceiveWatchCommand"
    }

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
            DLog("watchSession setup")
            session = WCSession.defaultSession()
            session!.delegate = delegate
            session!.activateSession()
        }
    }
    
    // MARK: - iOS Specific
#if os(iOS)
    func updateApplicationContext(mode: Mode) {
        guard let session = WatchSessionManager.sharedInstance.session where session.paired && session.watchAppInstalled else {
            return
        }
    
        if #available(iOS 9.3, *) {
            guard session.activationState == .Activated else {
                return
            }
        }
    
        do {
            let bleFoundPeripherals = BleManager.sharedInstance.blePeripheralsCount()
            var appContext: [String: AnyObject] = ["mode": mode.rawValue, "bleFoundPeripherals": bleFoundPeripherals]
            
            if let bleConnectedPeripheral = BleManager.sharedInstance.blePeripheralConnected {
                appContext["bleConnectedPeripheralName"] = bleConnectedPeripheral.name
                appContext["bleHasUart"] = bleConnectedPeripheral.isUartAdvertised()
            }
            try session.updateApplicationContext(appContext)
        }
        catch {
            //DLog("updateApplicationContext error")
        }
    }
#endif
}
