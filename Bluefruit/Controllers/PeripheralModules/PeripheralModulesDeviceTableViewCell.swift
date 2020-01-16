//
//  PeripheralModulesDeviceTableViewCell.swift
//  Bluefruit
//
//  Created by Antonio García on 22/06/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class PeripheralModulesDeviceTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rssiImageView: UIImageView!
    @IBOutlet weak var rssiLabel: UILabel!
    @IBOutlet weak var batteryImageView: UIImageView!
    @IBOutlet weak var batteryLabel: UILabel!
    @IBOutlet weak var batteryStackView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
