 //
 //  AppDelegate.swift
 //  bluefruitconnect
 //
 //  Created by Antonio García on 28/01/16.
 //  Copyright © 2016 Adafruit. All rights reserved.
 //
 
 import UIKit
 import WatchConnectivity
 
 @UIApplicationMain
 class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var splitDividerCover = UIView()
  

    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()
        
        // Watch Connectivity
      WatchSessionManager.sharedInstance.activateWithDelegate(delegate: self)
        
        // Check if there is any update to the fimware database
      FirmwareUpdater.refreshSoftwareUpdatesDatabase(from: Preferences.updateServerUrl! as URL, completionHandler: nil)
        
        // Setup SpliView
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        splitViewController.delegate = self
        
        // Style
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = UIColor.black
        //        navigationBarAppearance.alpha = 0.1
      navigationBarAppearance.isTranslucent = true
      navigationBarAppearance.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white]
        
        /*
         let tabBarAppearance = UITabBar.appearance()
         tabBarAppearance.barTintColor = UIColor.blackColor()
         */
        
        // Hack to hide the white split divider
      splitViewController.view.backgroundColor = UIColor.darkGray
      splitDividerCover.backgroundColor = UIColor.darkGray
        splitViewController.view.addSubview(splitDividerCover)
      self.splitViewController(splitViewController, willChangeTo: splitViewController.displayMode)
        
        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": true], replyHandler: nil, errorHandler: nil)
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": false], replyHandler: nil, errorHandler: nil)
        
    }
    
    
    // MARK: - Handoff
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return userActivityType == HandoffManager.kUserActivityType
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        
      DLog(message: "continueUserActivity: \(userActivity.activityType)")
        if userActivity.activityType == HandoffManager.kUserActivityType {
            
          DLog(message: "continueUserActivity true")
            return true
        }
        
      DLog(message: "continueUserActivity false")
        return false
    }
    
    func application(_ application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
      DLog(message: "didFailToContinueUserActivityWithType: \(userActivityType). Error: \(error)")
    }
  
 }
 
 // MARK: - UISplitViewControllerDelegate
 extension AppDelegate: UISplitViewControllerDelegate {
    
    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        
        if BleManager.sharedInstance.blePeripheralConnected == nil {
            return true
        }
        
        return false
    }
    
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewControllerDisplayMode) {
        // Hack to hide splitdivider cover
      let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
      let isCoverHidden = isFullScreen || displayMode != .allVisible
      splitDividerCover.isHidden = isCoverHidden
      DLog(message: "cover hidden: \(isCoverHidden)")
        if !isCoverHidden {
            let masterViewWidth = svc.primaryColumnWidth
            //let masterViewNavigationBarHeight = (svc.viewControllers[0] as! UINavigationController).navigationBar.bounds.size.height
            //splitDividerCover.frame = CGRectMake(masterViewWidth, 0, 1, masterViewNavigationBarHeight)
          splitDividerCover.frame = CGRect(x: masterViewWidth, y: 0, width: 1, height: svc.view.bounds.size.height)
          DLog(message: "cover frame: \(splitDividerCover.frame)")
        }
    }
  
 }
 
 // MARK: - WCSessionDelegate
 extension AppDelegate: WCSessionDelegate {
    func sessionReachabilityDidChange(_ session: WCSession) {
      DLog(message: "sessionReachabilityDidChange: \(session.isReachable ? "reachable":"not reachable")")
        
      if session.isReachable {
            // Update foreground status
        let isActive = UIApplication.shared.applicationState != .inactive
            WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": isActive], replyHandler: nil, errorHandler: nil)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if message["command"] != nil {
          DLog(message: "watchCommand notification")
          NotificationCenter.default.post(name: NSNotification.Name(rawValue: WatchSessionManager.Notifications.DidReceiveWatchCommand.rawValue), object: nil)
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
              DLog(message: "didReceiveMessage with unknown command: \(command)")
                break
            }
        }
        
        replyHandler(replyValues)
    }
    
    // Mandatory methods for XCode8
    @available(iOS 9.3, *)
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }

  func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
 }
 
 
