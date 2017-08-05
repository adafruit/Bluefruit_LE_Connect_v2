//
//  EmptyDetailsViewController.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 06/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class EmptyDetailsViewController: PeripheralModeViewController {

    // UI
    @IBOutlet weak var emptyLabel: UILabel!

    // Data
    fileprivate var isConnnecting = false
    fileprivate var isAnimating = false

    fileprivate var scanningAnimationVieWController: ScanningAnimationViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        setConnecting(isConnnecting)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)


    }

    func setConnecting(_ isConnecting: Bool) {
        self.isConnnecting = isConnecting

        loadViewIfNeeded()
        let localizationManager = LocalizationManager.sharedInstance
        emptyLabel.text = localizationManager.localizedString(isConnecting ? "peripheraldetails_connecting" : "peripheraldetails_select")
    }
    
    func setAdvertising(numServices: Int) {
        loadViewIfNeeded()
        //emptyLabel.text = String(format: "Advertising %ld custom services", numServices)
        emptyLabel.text = "Advertising..."
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ScanningAnimationViewControllerSegue" {
            scanningAnimationVieWController = (segue.destination as! ScanningAnimationViewController)
            if isAnimating {            // check if startAnimating was called before prepareForSegue was executed
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
