//
//  ModeTabsViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 03/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ModeTabsViewController: ScrollingTabBarViewController {

    /*
    // Parameters
    enum ModuleController {
        case central
        case peripheral
    }
    
    // Data
    */
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Tab ViewControllers
        var viewControllers = [UIViewController]()
        
        
        if let scannerViewController = self.storyboard?.instantiateViewController(withIdentifier: "ScannerViewController") as? ScannerViewController  {
            // Add scanner to tabs content viewcontroller
            scannerViewController.tabBarItem.title = "Central Mode"      // Tab title
            scannerViewController.tabBarItem.image = UIImage(named: "tab_centralmode_icon")
            viewControllers.append(scannerViewController)
        }
        
        if let gattServerViewController = self.storyboard?.instantiateViewController(withIdentifier: "GattServerViewController") as? GattServerViewController {
            
             // Add advertiser to tabs content viewcontroller
            gattServerViewController.tabBarItem.title = "Peripheral Mode"      // Tab title
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
            
            // Change the detail viewcontroller
            if let modeTabViewController = viewController as? ModeTabViewController {
                if let detailViewController = modeTabViewController.detailViewController() {
                    showDetailViewController(detailViewController, sender: self)
                }
            }
        }
    }
    
    /*
    override func selectedIndexDidChange() {
        guard selectedIndex >= 0 && selectedIndex < viewControllers.count else { DLog("Wrong index"); return }
        
        let navigationController = detailViewControllers[selectedIndex]
        showDetailViewController(navigationController, sender: self)
    }*/
}
