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
        layer.borderColor =  titleColor(for: .normal)?.cgColor //tintColor.CGColor
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
    
    override func setTitleColor(_ color: UIColor?, for state: UIControlState) {
        super.setTitleColor(color, for: state)
        if let color = color {
            layer.borderColor = color.cgColor
        }
    }
}
