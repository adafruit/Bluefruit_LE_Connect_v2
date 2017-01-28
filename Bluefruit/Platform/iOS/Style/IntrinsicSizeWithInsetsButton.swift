//
//  IntrinsicSizeWithInsetsButton.swift
//  Bluefruit Calibration
//
//  Created by Antonio García on 24/10/2016.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import UIKit

class IntrinsicSizeWithInsetsButton: UIButton {

    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + titleEdgeInsets.left + titleEdgeInsets.right, height: s.height + titleEdgeInsets.top + titleEdgeInsets.bottom)
    }
}
