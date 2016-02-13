//
//  ControllerSensorTableViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 12/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ControllerSensorTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var enableSwitch: UISwitch!
    
    var onSensorEnabled : ((Bool)->())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBAction func onEnabledValueChanged(sender: UISwitch) {
        onSensorEnabled?(sender.on)
    }
}
