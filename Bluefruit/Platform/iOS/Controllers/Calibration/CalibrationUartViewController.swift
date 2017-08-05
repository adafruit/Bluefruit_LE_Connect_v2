//
//  CalibrationUartViewController.swift
//  Calibration
//
//  Created by Antonio García on 15/11/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class CalibrationUartViewController: UIViewController {

    weak var blePeripheral: BlePeripheral?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

// MARK: - String first character to ascii
extension String {
    // Use only for known strings
    var asciiValue: UInt8 {
        return UInt8(unicodeScalars.first?.value ?? 0)
    }
}
