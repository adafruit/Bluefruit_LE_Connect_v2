//
//  MagnetometerPageMatrixViewController.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class MagnetometerPageMatrixViewController: MagnetometerPageContentViewController {

    // UI
    @IBOutlet weak var valuesStackView: UIStackView!
    @IBOutlet weak var magneticFieldLabel: UILabel!
    @IBOutlet weak var magneticOffsetLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func updateUI() {
        super.updateUI()

        guard let calibration = calibration else {
            return
        }

        // Offset
        let magneticOffset = calibration.magneticOffset()

        magneticOffsetLabel.text = String(format: "( %.2f  %.2f  %.2f) ", magneticOffset.x, magneticOffset.y, magneticOffset.z)

        // Mapping
        let magneticMapping = calibration.magneticMapping()
        for (j, rowView) in valuesStackView.arrangedSubviews.enumerated() {
            for (i, valueView) in (rowView as! UIStackView).arrangedSubviews.enumerated() {
                let valueLabel = valueView as! UILabel
                valueLabel.text = String(format: "%+.3f", magneticMapping[i, j])
            }
        }

        // Field
        let magneticField = calibration.magneticField()
        magneticFieldLabel.text = String(format: "%.2f", magneticField)

    }
}
