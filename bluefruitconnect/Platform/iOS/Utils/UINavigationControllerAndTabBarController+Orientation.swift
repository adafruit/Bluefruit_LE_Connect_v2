//
//  UINavigationControllerAndTabBarController+Orientation.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation


extension UINavigationController {
    
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if let visibleViewController = visibleViewController {
            return visibleViewController.supportedInterfaceOrientations()
        }
        else {
            return super.supportedInterfaceOrientations()
        }
    }
    
    public override func shouldAutorotate() -> Bool {
        if let visibleViewController = visibleViewController {
            return visibleViewController.shouldAutorotate()
        }
        else {
            return super.shouldAutorotate()
        }
    }
}

extension UITabBarController {
    public override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if let selectedViewController = selectedViewController {
            return selectedViewController.supportedInterfaceOrientations()
        }
        else {
            return super.supportedInterfaceOrientations()
        }
    }

    public override func shouldAutorotate() -> Bool {
        if let selected = selectedViewController {
            return selected.shouldAutorotate()
        }
        else {
            return super.shouldAutorotate()
        }
    }
}