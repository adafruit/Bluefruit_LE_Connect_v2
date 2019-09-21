//
//  TraitOverrideContainerViewController.swift
//  iOS
//
//  Created by Antonio García on 21/09/2019.
//  Copyright © 2019 Adafruit. All rights reserved.
//

import UIKit

class TraitOverrideContainerViewController: UIViewController {
    
    // UI
    private var embeddedSplitViewController: UISplitViewController?
  
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
            
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Force iphone plus/max to behave like an standard iphone (to avoid disconnection problems when rotating). If removed check that "ScannerViewController -> viewWillAppear -> autodisconnection when only 1 connected peripheral" won't force an disconnect incorrectly
        if UI_USER_INTERFACE_IDIOM() == .phone {
            let horizontalTraitCollection = UITraitCollection(horizontalSizeClass: .compact)
            setOverrideTraitCollection(horizontalTraitCollection, forChild: embeddedSplitViewController!)
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? UISplitViewController {
            embeddedSplitViewController = viewController
        }
    }

}
