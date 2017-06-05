//
//  PeripheralModulesTableViewCell.swift
//  Bluefruit
//
//  Created by Antonio García on 05/06/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class PeripheralModulesTableViewCell: UITableViewCell {

    // UI
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!

    // MARK: - View Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
