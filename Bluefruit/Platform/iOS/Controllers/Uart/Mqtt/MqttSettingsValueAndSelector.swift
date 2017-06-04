//
//  MqttSettingsValueAndSelector.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class MqttSettingsValueAndSelector: UITableViewCell {

    // UI
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueTextField: UITextField?
    @IBOutlet weak var typeButton: UIButton?

    // Data
    var indexPath: NSIndexPath?

    func reset() {
        valueTextField?.text = nil
        valueTextField?.placeholder = nil
        valueTextField?.keyboardType = UIKeyboardType.default
    }
}
