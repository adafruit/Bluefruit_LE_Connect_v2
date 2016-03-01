//
//  ModuleViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 28/01/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ModuleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = StyleConfig.backgroundColor
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Setup navigation item
        if let parentNavigationItem = parentViewController?.navigationItem {

            // Setup navigation item title and buttons
            parentNavigationItem.title = navigationItem.title
            parentNavigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

