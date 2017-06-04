//
//  StyledButton.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class StyledButton: IntrinsicSizeWithInsetsButton {

    override func awakeFromNib() {
        super.awakeFromNib()

        layer.borderColor = tintColor.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 8
        layer.masksToBounds = true
        backgroundColor = UIColor.white.withAlphaComponent(0.8)
        backgroundColor = UIColor.clear
    }
}
