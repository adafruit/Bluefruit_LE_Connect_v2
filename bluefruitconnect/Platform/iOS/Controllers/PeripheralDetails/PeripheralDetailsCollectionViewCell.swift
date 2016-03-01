//
//  PeripheralDetailsCollectionViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/03/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class PeripheralDetailsCollectionViewCell: UICollectionViewCell {
    // UI
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    override var selected: Bool {
        didSet {
            let tintColor = selected ? self.tintColor:UIColor.lightGrayColor()
            titleLabel.textColor = tintColor
            iconImageView.tintColor = tintColor
        }
    }

    
}
