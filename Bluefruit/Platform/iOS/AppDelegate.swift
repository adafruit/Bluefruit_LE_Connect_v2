//
//  AppDelegate.swift
//  Bluefruit
//
//  Created by Antonio on 26/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    fileprivate var splitDividerCover = UIView()


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
  
        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()
  
        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabase(url: Preferences.updateServerUrl, completion: nil)
        
        // Setup SpliView
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        splitViewController.delegate = self
        
        // Style
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = UIColor.black
        navigationBarAppearance.isTranslucent = true
        navigationBarAppearance.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]

        // Hack to hide the white split divider
        splitViewController.view.backgroundColor = UIColor.darkGray
        splitDividerCover.backgroundColor = UIColor.darkGray
        splitViewController.view.addSubview(splitDividerCover)
        self.splitViewController(splitViewController, willChangeTo: splitViewController.displayMode)
        
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
    }
}

// MARK: - UISplitViewControllerDelegate
extension AppDelegate: UISplitViewControllerDelegate {
    
    
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        
        let connectedPeripherals = BleManager.sharedInstance.connectedPeripherals()
        return connectedPeripherals.isEmpty
    }
    
    
    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewControllerDisplayMode) {
        // Hack to hide splitdivider cover
        let isFullScreen = UIScreen.main.traitCollection.horizontalSizeClass == .compact
        let isCoverHidden = isFullScreen || displayMode != .allVisible
        splitDividerCover.isHidden = isCoverHidden
//        DLog("cover hidden: \(isCoverHidden)")
        if !isCoverHidden {
            let masterViewWidth = svc.primaryColumnWidth
            splitDividerCover.frame = CGRect(x: masterViewWidth, y: 0, width: 1, height: svc.view.bounds.size.height)
//            DLog("cover frame: \(splitDividerCover.frame)")
        }
    }
}
