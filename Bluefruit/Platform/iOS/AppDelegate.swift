//
//  AppDelegate.swift
//  Bluefruit
//
//  Created by Antonio on 26/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()

        // Watch Connectivity
        WatchSessionManager.sharedInstance.activate(with: self)

        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: Preferences.updateServerUrl, completion: nil)

        // Style
        
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = UIColor.black
        navigationBarAppearance.isTranslucent = true
        navigationBarAppearance.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]

        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": true], replyHandler: nil, errorHandler: nil)

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": false], replyHandler: nil, errorHandler: nil)

    }
}

// MARK: - WCSessionDelegate
extension AppDelegate: WCSessionDelegate {
    func sessionReachabilityDidChange(_ session: WCSession) {
        DLog("sessionReachabilityDidChange: \(session.isReachable ? "reachable":"not reachable")")

        if session.isReachable {
            // Update foreground status
            let isActive = UIApplication.shared.applicationState != .inactive
            WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": isActive], replyHandler: nil, errorHandler: nil)

            NotificationCenter.default.post(name: .watchSessionDidBecomeActive, object: nil, userInfo: nil)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if message["command"] != nil {
            DLog("watchCommand notification")
            NotificationCenter.default.post(name: .didReceiveWatchCommand, object: nil, userInfo: message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        var replyValues: [String: AnyObject] = [:]

        if let command = message["command"] as? String {
            switch command {
            case "isActive":
                let isActive = UIApplication.shared.applicationState != .inactive
                replyValues[command] = isActive as AnyObject

            default:
                DLog("didReceiveMessage with unknown command: \(command)")
            }
        }

        replyHandler(replyValues)
    }

    @available(iOS 9.3, *)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DLog("activationDidCompleteWithState: \(activationState.rawValue)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DLog("sessionDidBecomeInactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DLog("sessionDidDeactivate")
    }
}
