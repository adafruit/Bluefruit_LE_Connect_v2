 //
//  AppDelegate.swift
//  bluefruitconnect
//
//  Created by Antonio García on 28/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?
    private var splitDividerCover = UIView()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        // Register default preferences
        //Preferences.resetDefaults()       // Debug Reset
        Preferences.registerDefaults()
        
        // Check if there is any update to the fimware database
        FirmwareUpdater.refreshSoftwareUpdatesDatabaseWithCompletionHandler(nil)
        
        // Setup SpliView
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        splitViewController.delegate = self

        // Style
        let navigationBarAppearance = UINavigationBar.appearance()
        navigationBarAppearance.barTintColor = UIColor.blackColor()
//        navigationBarAppearance.alpha = 0.1
        navigationBarAppearance.translucent = true
        navigationBarAppearance.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        
        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.barTintColor = UIColor.blackColor()
        
        // Hack to hide the white split divider
        splitViewController.view.backgroundColor = UIColor.darkGrayColor()
        splitDividerCover.backgroundColor = UIColor.darkGrayColor()
        splitViewController.view.addSubview(splitDividerCover)
        self.splitViewController(splitViewController, willChangeToDisplayMode: splitViewController.displayMode)
 
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
    }

    // MARK: - Split view
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


