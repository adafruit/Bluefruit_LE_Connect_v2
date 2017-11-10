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

    // Constants
    static let kContextModeKey = "mode"
    enum Mode: String {
        case inactive = "MainInterfaceController"
        case scan = "ScanningInterfaceController"
        case connected = "ConnectedInterfaceController"
        case controller = "ControlModeInterfaceController"
    }

    // Singleton
    static let sharedInstance = WatchSessionManager()

    // Data
    var session: WCSession?

    //
    func activate(with delegate: WCSessionDelegate?) {
        if WCSession.isSupported() {
            DLog("watchSession setup")
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
            let peripheralsCount = BleManager.sharedInstance.peripherals().count
            var appContext: [String: Any] = ["mode": mode.rawValue, "bleFoundPeripherals": peripheralsCount]

            if let bleConnectedPeripheral = BleManager.sharedInstance.connectedPeripherals().first {
                appContext["bleConnectedPeripheralName"] = bleConnectedPeripheral.name
                appContext["bleHasUart"] = bleConnectedPeripheral.isUartAdvertised()
            }
            try session.updateApplicationContext(appContext)
        } catch {
            //DLog("updateApplicationContext error")
        }
    }
    #endif
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kNotificationsPrefix = Bundle.main.bundleIdentifier!
    static let didReceiveWatchCommand = Notification.Name(kNotificationsPrefix+".didReceiveWatchCommand")
    static let watchSessionDidBecomeActive = Notification.Name(kNotificationsPrefix+".watchSessionDidBecomeActive")
}
