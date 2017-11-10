//
//  ModeTabsViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 03/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ModeTabsViewController: ScrollingTabBarViewController {

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Tab ViewControllers
        var viewControllers = [ModeTabViewController]()
        
        let localizationManager = LocalizationManager.sharedInstance
        if let scannerViewController = self.storyboard?.instantiateViewController(withIdentifier: "ScannerViewController") as? ScannerViewController  {
            // Add scanner to tabs content viewcontroller
            scannerViewController.tabBarItem.title = localizationManager.localizedString("main_tabbar_centralmode")      // Tab title
            scannerViewController.tabBarItem.image = UIImage(named: "tab_centralmode_icon")
            viewControllers.append(scannerViewController)
        }
        
        if let gattServerViewController = self.storyboard?.instantiateViewController(withIdentifier: "GattServerViewController") as? GattServerViewController {
            
             // Add advertiser to tabs content viewcontroller
            gattServerViewController.tabBarItem.title =  localizationManager.localizedString("main_tabbar_peripheralmode")       // Tab title
            gattServerViewController.tabBarItem.image = UIImage(named: "tab_peripheralmode_icon")
            viewControllers.append(gattServerViewController)
        }
        
        setViewControllers(viewControllers, animated: false)
        selectedIndex = 0
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func changeSelectedViewController(_ viewController: UIViewController?) {
        super.changeSelectedViewController(viewController)
        
        // Copy child navigation item
        if let viewController = viewController {
            // Copy viewcontroller navigationItem to our navigationItem
            navigationItem.title = viewController.navigationItem.title
            navigationItem.rightBarButtonItems = viewController.navigationItem.rightBarButtonItems
            
            // Change the detail viewcontroller if in regular horizontal class
            if let horizontalSizeClass = splitViewController?.traitCollection.horizontalSizeClass {
                if horizontalSizeClass == .regular {
                    if let modeTabViewController = viewController as? ModeTabViewController {
                        if let detailViewController = modeTabViewController.detailViewController() {
                            showDetailViewController(detailViewController, sender: self)
                        }
                    }
                }
            }
        }
    }
    
    override func selectedIndexDidChange(from: Int, to:Int) {
        guard let viewControllers = viewControllers else { return }
        
        if to >= 0 && to < viewControllers.count {
            (viewControllers[to] as? ModeTabViewController)?.tabShown()
        }

        if from >= 0 && from < viewControllers.count {
            (viewControllers[from] as? ModeTabViewController)?.tabHidden()
        }
    }
}
