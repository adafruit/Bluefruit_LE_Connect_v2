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
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()
        
        // Watch Connectivity
        WatchSessionManager.sharedInstance.activateWithDelegate(self)
        
        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabaseFromUrl(Preferences.updateServerUrl, completionHandler: nil)
        
        // Setup SpliView
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        splitViewController.delegate = self
        
        // Style
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = UIColor.blackColor()
        //        navigationBarAppearance.alpha = 0.1
        navigationBarAppearance.translucent = true
        navigationBarAppearance.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        
        /*
         let tabBarAppearance = UITabBar.appearance()
         tabBarAppearance.barTintColor = UIColor.blackColor()
         */
        
        // Hack to hide the white split divider
        splitViewController.view.backgroundColor = UIColor.darkGrayColor()
        splitDividerCover.backgroundColor = UIColor.darkGrayColor()
        splitViewController.view.addSubview(splitDividerCover)
        self.splitViewController(splitViewController, willChangeToDisplayMode: splitViewController.displayMode)
        
        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": true], replyHandler: nil, errorHandler: nil)
        
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Watch Session
        WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": false], replyHandler: nil, errorHandler: nil)
        
    }
    
    
    // MARK: - Handoff
    func application(application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return userActivityType == HandoffManager.kUserActivityType
    }
    
    func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        
        DLog("continueUserActivity: \(userActivity.activityType)")
        if userActivity.activityType == HandoffManager.kUserActivityType {
            
            DLog("continueUserActivity true")
            return true
        }
        
        DLog("continueUserActivity false")
        return false
    }
    
    func application(application: UIApplication, didFailToContinueUserActivityWithType userActivityType: String, error: NSError) {
        DLog("didFailToContinueUserActivityWithType: \(userActivityType). Error: \(error)")
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
    
    func splitViewController(svc: UISplitViewController, willChangeToDisplayMode displayMode: UISplitViewControllerDisplayMode) {
        // Hack to hide splitdivider cover
        let isFullScreen = UIScreen.mainScreen().traitCollection.horizontalSizeClass == .Compact
        let isCoverHidden = isFullScreen || displayMode != .AllVisible
        splitDividerCover.hidden = isCoverHidden
        DLog("cover hidden: \(isCoverHidden)")
        if !isCoverHidden {
            let masterViewWidth = svc.primaryColumnWidth
            //let masterViewNavigationBarHeight = (svc.viewControllers[0] as! UINavigationController).navigationBar.bounds.size.height
            //splitDividerCover.frame = CGRectMake(masterViewWidth, 0, 1, masterViewNavigationBarHeight)
            splitDividerCover.frame = CGRectMake(masterViewWidth, 0, 1, svc.view.bounds.size.height)
            DLog("cover frame: \(splitDividerCover.frame)")
            
        }
    }
 }
 
 // MARK: - WCSessionDelegate
 extension AppDelegate: WCSessionDelegate {
    func sessionReachabilityDidChange(session: WCSession) {
        DLog("sessionReachabilityDidChange: \(session.reachable ? "reachable":"not reachable")")
        
        if session.reachable {
            // Update foreground status
            let isActive = UIApplication.sharedApplication().applicationState != .Inactive
            WatchSessionManager.sharedInstance.session?.sendMessage(["isActive": isActive], replyHandler: nil, errorHandler: nil)
        }
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        if message["command"] != nil {
            DLog("watchCommand notification")
            NSNotificationCenter.defaultCenter().postNotificationName(WatchSessionManager.Notifications.DidReceiveWatchCommand.rawValue, object: nil, userInfo:message);
        }
    }
    
    func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        var replyValues: [String: AnyObject] = [:]
        
        if let command = message["command"] as? String {
            switch command {
            case "isActive":
                let isActive = UIApplication.sharedApplication().applicationState != .Inactive
                replyValues[command] = isActive

            default:
                DLog("didReceiveMessage with unknown command: \(command)")
                break
            }
        }
        
        replyHandler(replyValues)
    }
    

 }
 
 
