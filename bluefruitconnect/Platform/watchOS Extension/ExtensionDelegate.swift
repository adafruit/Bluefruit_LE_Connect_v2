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

    var isWaitingForSessionActivation = true
    
    func applicationDidFinishLaunching() {
        
        if (WCSession.isSupported()) {
            DLog("watchSession setup")
            let session = WCSession.defaultSession()
            session.delegate = self
            session.activateSession()
        }
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
}


extension ExtensionDelegate: WCSessionDelegate{
    func sessionReachabilityDidChange(session: WCSession) {
        DLog("sessionReachabilityDidChange: \(session.activationState)")
        
        if session.activationState == .Activated {
            if isWaitingForSessionActivation {
                WKInterfaceController.reloadRootControllersWithNames(["ScanningInterfaceController"], contexts: nil)
                isWaitingForSessionActivation = false
            }
        }
        else {
            if !isWaitingForSessionActivation {
                WKInterfaceController.reloadRootControllersWithNames(["MainInterfaceController"], contexts: nil)
                isWaitingForSessionActivation = true
            }
        }
    }
    
    func sessionDidBecomeInactive(session: WCSession) {
        DLog("sessionDidBecomeInactive")
    }
    
    
}
