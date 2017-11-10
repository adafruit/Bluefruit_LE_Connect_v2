//
//  PeripheralServiceViewController.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class PeripheralServiceViewController: UIViewController {
    
    // Data
    private var emptyViewController: EmptyDetailsViewController?

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        emptyViewController = storyboard?.instantiateViewController(withIdentifier: "EmptyDetailsViewController") as? EmptyDetailsViewController
        
        showEmpty(true)
        emptyViewController?.setAdvertising(numServices: 0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: -
    func showEmpty(_ showEmpty: Bool) {
        
        if showEmpty {
            // Show empty view (if needed)
            if let viewController = emptyViewController, viewController.view.superview == nil {
                
                if let containerView = self.view, let subview = viewController.view {
                    subview.translatesAutoresizingMaskIntoConstraints = false
                    self.addChildViewController(viewController)
                    
                    viewController.beginAppearanceTransition(true, animated: true)
                    containerView.addSubview(subview)
                    viewController.endAppearanceTransition()
                    
                    let dictionaryOfVariableBindings = ["subview": subview]
                    containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
                    containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[subview]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: dictionaryOfVariableBindings))
                    
                    viewController.didMove(toParentViewController: self)
                }
            }
            
            emptyViewController?.startAnimating()
        } else {
            emptyViewController?.stopAnimating()
            
            if let viewController = emptyViewController {
                viewController.willMove(toParentViewController: nil)
                viewController.view.removeFromSuperview()
                viewController.removeFromParentViewController()
            }
        }
    }
}
