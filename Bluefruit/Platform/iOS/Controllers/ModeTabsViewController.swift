//
//  ModeTabsViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 03/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ModeTabsViewController: ScrollingTabBarViewController {

    // Parameters
    enum ModuleController {
        case peripheral
        case central
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add Tab ViewControllers
        var viewControllers = [UIViewController]()
        if let scannerViewController = self.storyboard?.instantiateViewController(withIdentifier: "ScannerViewController") as? ScannerViewController {
            scannerViewController.tabBarItem.title = "Central Mode"      // Tab title
            scannerViewController.tabBarItem.image = UIImage(named: "tab_centralmode_icon")
            viewControllers.append(scannerViewController)
        }
        if let gattServerViewController = self.storyboard?.instantiateViewController(withIdentifier: "GattServerViewController") as? GattServerViewController {
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
            navigationItem.title = viewController.navigationItem.title
            navigationItem.rightBarButtonItems = viewController.navigationItem.rightBarButtonItems
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
