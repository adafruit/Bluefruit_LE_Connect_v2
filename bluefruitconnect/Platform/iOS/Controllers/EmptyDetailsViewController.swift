//
//  EmptyDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class EmptyDetailsViewController: ModuleViewController {

    // UI
    @IBOutlet weak var emptyLabel: UILabel!

    // Data
    private var isConnnecting = false
    private var isAnimating = false

    private var scanningAnimationVieWController: ScanningAnimationViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setConnecting(isConnnecting)
    }
    
    func setConnecting(isConnecting : Bool) {
        self.isConnnecting = isConnecting
        
        let localizationManager = LocalizationManager.sharedInstance
        emptyLabel?.text = localizationManager.localizedString(isConnecting ? "peripheraldetails_connecting" : "peripheraldetails_select")
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ScanningAnimationViewControllerSegue"  {
            scanningAnimationVieWController = (segue.destinationViewController as! ScanningAnimationViewController)
            if isAnimating {            // check if startAnimating was called before preprareForSegue was executed
                startAnimating()
            }
        }
    }

    
    func startAnimating() {
        isAnimating = true
        scanningAnimationVieWController?.startAnimating()
    }
    
    func stopAnimating() {
        isAnimating = false
        scanningAnimationVieWController?.stopAnimating()
    }
}
