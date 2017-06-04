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

    var currentMode = WatchSessionManager.Mode.inactive
    var watchSession: WCSession?

    func applicationDidFinishLaunching() {

        // Watch Connectivity
        WatchSessionManager.sharedInstance.activate(with: self)
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.

    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompleted()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompleted()
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompleted()
            default:
                // make sure to complete unhandled task types
                task.setTaskCompleted()
            }
        }
    }

    // MARK: - Actions
    fileprivate func updatedHostedAppForegroundStatus(isActive: Bool) {
        DLog("isActive: \(isActive)")

        if isActive && currentMode == WatchSessionManager.Mode.inactive {

            if let appContext = WatchSessionManager.sharedInstance.session?.receivedApplicationContext, let modeString = appContext["mode"] as? String, let mode = WatchSessionManager.Mode(rawValue: modeString) {
                updateMode(mode)
            }
        } else if !isActive && currentMode != WatchSessionManager.Mode.inactive {
            updateMode(.inactive)
        }
    }

    fileprivate func updateMode(_ mode: WatchSessionManager.Mode) {
        if currentMode != mode {
            WKInterfaceController.reloadRootControllers(withNames: [mode.rawValue], contexts: nil)
            currentMode = mode
        }
    }
}

// MARK: - WCSessionDelegate
extension ExtensionDelegate: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DLog("activationDidCompleteWithState: \(session.activationState.rawValue)")

        // Ask if host app is active
        session.sendMessage(["command": "isActive"], replyHandler: { [weak self] (response) in
            let isActive = (response["isActive"] as AnyObject).boolValue == true
            self?.updatedHostedAppForegroundStatus(isActive: isActive)
            }) { (error) in
                DLog("isActive error: \(error)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        for command in message {
            DLog("didReceiveMessage with command: \(command)")
            switch command {
            case ("isActive", let isActive):
                updatedHostedAppForegroundStatus(isActive: isActive as! Bool)

            default:
                DLog("didReceiveMessage with unknown command: \(command)")
                break
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        //DLog("ExtensionDelegate didReceiveApplicationContext: \(applicationContext)")

        if let modeString = applicationContext[WatchSessionManager.kContextModeKey] as? String, let mode = WatchSessionManager.Mode(rawValue: modeString) {
            let rootController = WKExtension.shared().rootInterfaceController

            switch mode {

            case .scan:
                if let scanningInterfaceController = rootController as? ScanningInterfaceController {
                    scanningInterfaceController.didReceiveApplicationContext(applicationContext)
                } else {
                    updateMode(mode)
                }

            case .connected:
                if let connectedInterfaceController = rootController as? ConnectedInterfaceController {
                    connectedInterfaceController.didReceiveApplicationContext(applicationContext)
                } else {
                    updateMode(mode)
                }

            case .controller:
                if !(rootController is ControlModeInterfaceController) {
                    updateMode(mode)
                }

            default:
                DLog("ExtensionDelegate didReceiveApplicationContext with unknown mode: \(mode.rawValue)")
                break
            }
        }
    }

}
