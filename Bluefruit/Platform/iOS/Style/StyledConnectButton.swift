//
//  StyledButton.swift
//  Calibration
//
//  Created by Antonio on 09/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

class StyledConnectButton: IntrinsicSizeWithInsetsButton {

    fileprivate let borderView = UIView()

    override func awakeFromNib() {
        super.awakeFromNib()

        // Background
        backgroundColor = UIColor.white.withAlphaComponent(0.8)
        backgroundColor = UIColor.clear

        // Internal subview to draw border. titleEdgeInsets are used as margins
        borderView.layer.borderColor = tintColor.cgColor
        borderView.layer.borderWidth = 1
        borderView.layer.cornerRadius = 8
        borderView.layer.masksToBounds = true
        borderView.backgroundColor = UIColor.clear
        borderView.isUserInteractionEnabled = false
        addSubview(borderView)

//        #if DEBUG
//        layer.borderColor = UIColor.red.cgColor
//        layer.borderWidth = 1
//        #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let insets = titleEdgeInsets
        borderView.frame = CGRect(x: insets.left, y: insets.top, width: bounds.size.width - insets.left - insets.right, height: bounds.size.height - insets.top - insets.bottom)
    }
}
