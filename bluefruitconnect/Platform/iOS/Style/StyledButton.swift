//
//  StyledButton.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 15/02/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

@IBDesignable
class StyledButton: UIButton {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderWidth = 1
        layer.borderColor =  titleColorForState(.Normal)?.CGColor //tintColor.CGColor
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
    
    override func setTitleColor(color: UIColor?, forState state: UIControlState) {
        super.setTitleColor(color, forState: state)
        if let color = color {
            layer.borderColor = color.CGColor
        }
    }
}
