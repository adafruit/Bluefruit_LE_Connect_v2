//
//  ServiceTableViewCell.swift
//  Bluefruit
//
//  Created by Antonio García on 04/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class ServiceTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var enabledSwitch: UISwitch!

    // Params
    var isEnabledChanged: ((Bool) -> Void)?
    
    // MARK: - View Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    // MARK: - Actions
    @IBAction func onEnabledValueChanged(_ sender: UISwitch) {
        isEnabledChanged?(sender.isOn)
    }
}
