//
//  MqqtSettingsStatusCell.swift
//  Adafruit Bluefruit LE Connect
//
//  Created by Antonio García on 30/07/15.
//  Copyright (c) 2015 Adafruit Industries. All rights reserved.
//

import UIKit

class MqttSettingsStatusCell: UITableViewCell {

    // UI
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var waitView: UIActivityIndicatorView!

    // Data
    var onClickAction : (() -> Void)?

    @IBAction func onClickButton(_ sender: AnyObject) {
        self.onClickAction?()
    }
}
