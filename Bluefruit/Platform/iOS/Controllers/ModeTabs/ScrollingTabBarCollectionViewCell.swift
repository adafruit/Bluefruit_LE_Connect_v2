//
//  ScrollingTabBarCollectionViewCell.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/03/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ScrollingTabBarCollectionViewCell: UICollectionViewCell {
    // UI
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    override var isSelected: Bool {
        didSet {
            let tintColor = isSelected ? self.tintColor:UIColor.lightGray
            titleLabel.textColor = tintColor
            iconImageView.tintColor = tintColor
        }
    }
}
