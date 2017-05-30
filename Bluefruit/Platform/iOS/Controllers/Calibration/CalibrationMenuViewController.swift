//
//  MainMenuViewController.swift
//  Calibration
//
//  Created by Antonio on 11/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class CalibrationMenuViewController: UartViewController {
    
    @IBOutlet weak var menuStackView: UIStackView!
    @IBOutlet weak var magnetometerButton: StyledLinkedButton!
    @IBOutlet weak var gyroscopeButton: StyledLinkedButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        for view in menuStackView.arrangedSubviews {
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? UartViewController {
            viewController.blePeripheral = blePeripheral
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    /*
    deinit {
        // Disconnect from peripheral on exit
        
        if let peripheral = blePeripheral {
            DLog("Disconnect from current peripheral")
            BleManager.sharedInstance.disconnect(from: peripheral)
        }
        else {
            DLog("Cannot disconnect because peripheral is undefined")
        }
    }*/
}

