//
//  GyroscopePageDataViewController.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class GyroscopePageDataViewController: GyroscopePageContentViewController {

    // UI
    @IBOutlet weak var gyroscopeOffsetLabel: UILabel!
    @IBOutlet weak var unitsSegmentedControl: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        unitsSegmentedControl.selectedSegmentIndex = Preferences.gyroUnitId
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func updateUI() {
        super.updateUI()

        guard let gyroVector = gyroVector else {
            return
        }

        var value: Vector3
        var unitFormat: String
        switch Preferences.gyroUnitId {
        case 1:
            value = gyroVector * Calibration.GyroSensor.degPerSecPerCount
            unitFormat = "%.2f"
        case 2:
            value = gyroVector * Calibration.GyroSensor.degPerSecPerCount
            value = Vector3(value.x.degreesToRadians, value.y.degreesToRadians, value.z.degreesToRadians)
            unitFormat = "%.4f"
        default:
            value = gyroVector
            unitFormat = "%.0f"
        }

        // Average Readings
        gyroscopeOffsetLabel.text = String(format: "( \(unitFormat)  \(unitFormat)  \(unitFormat)) ", value.x, value.y, value.z)
    }

    @IBAction func onUnitsChanged(_ sender: UISegmentedControl) {
        Preferences.gyroUnitId = sender.selectedSegmentIndex

        updateUI()
    }

}
