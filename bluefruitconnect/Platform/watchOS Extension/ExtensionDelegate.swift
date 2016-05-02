//
//  ExtensionDelegate.swift
//  watchOS Extension
//
//  Created by Antonio García on 01/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    var currentMode = WatchSessionManager.Mode.Inactive
    var watchSession: WCSession?
    
    func applicationDidFinishLaunching() {
        
        // Watch Connectivity
        WatchSessionManager.sharedInstance.activateWithDelegate(self)
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        
    }
}

extension ExtensionDelegate: WCSessionDelegate {
    func session(session: WCSession, activationDidCompleteWithState activationState: WCSessionActivationState, error: NSError?) {
        DLog("activationDidCompleteWithState: \(session.activationState.rawValue)")
        
        // Ask if host app is active
        session.sendMessage(["command": "isActive"], replyHandler: { [weak self] (response) in
            let isActive = response["isActive"]?.boolValue == true
            self?.updatedHostedAppForegroundStatus(isActive)
            }) { (error) in
                DLog("isActive error: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(session: WCSession) {
        DLog("sessionDidBecomeInactive")
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        
        for command in message {
            DLog("didReceiveMessage with command: \(command)")
            switch command {
            case ("isActive", let isActive):
                updatedHostedAppForegroundStatus(isActive.boolValue)
                
            default:
                DLog("didReceiveMessage with unknown command: \(command)")
                break
            }
        }
    }
    
    func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        DLog("ExtensionDelegate didReceiveApplicationContext: \(applicationContext)")
        
        if let modeString = applicationContext["mode"] as? String, let mode = WatchSessionManager.Mode(rawValue: modeString)  {
            let rootController = WKExtension.sharedExtension().rootInterfaceController
            switch mode {
            case .Scan:
                if let scanningInterfaceController = rootController as? ScanningInterfaceController {
                    scanningInterfaceController.didReceiveApplicationContext(applicationContext)
                }
                else {
                    updateMode(mode)
                }
                
            case .Connected:
                if let connectedInterfaceController = rootController as? ConnectedInterfaceController {
                    connectedInterfaceController.didReceiveApplicationContext(applicationContext)
                }
                else {
                    updateMode(mode)
                }
                
            case .Controller:
                if !(rootController is ControlModeInterfaceController) {
                    updateMode(mode)
                }
                
            default:
                DLog("ExtensionDelegate didReceiveApplicationContext with unknown mode: \(mode.rawValue)")
                break

            }
        }
    }
    
    // MARK: - Actions
    private func updatedHostedAppForegroundStatus(isActive: Bool) {
        DLog("isActive: \(isActive)")

        if isActive && currentMode == WatchSessionManager.Mode.Inactive {
            
            if let appContext = WatchSessionManager.sharedInstance.session?.receivedApplicationContext, let modeString = appContext["mode"] as? String, let mode = WatchSessionManager.Mode(rawValue: modeString) {
                updateMode(mode)
            }
            
        }
        else if !isActive && currentMode != WatchSessionManager.Mode.Inactive {
            updateMode(.Inactive)
        }
    }
    
    private func updateMode(mode: WatchSessionManager.Mode) {
        if currentMode != mode {
            WKInterfaceController.reloadRootControllersWithNames([mode.rawValue], contexts: nil)
            currentMode = mode
        }
    }
}
