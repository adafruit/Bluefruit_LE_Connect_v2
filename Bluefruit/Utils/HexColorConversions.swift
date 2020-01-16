//
//  HexColorConversions.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 02/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

// MARK: - Colors
func colorHexString(_ color: UIColor) -> String {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0

    color.getRed(&r, green: &g, blue: &b, alpha: &a)

    let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0

    return String(format:"#%06x", rgb).uppercased()
}

func colorHexInt(_ color: UIColor) -> Int {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0

    color.getRed(&r, green: &g, blue: &b, alpha: &a)

    let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
    return rgb
}

#if os(iOS)    
    func colorFrom(hex: UInt) -> UIColor? {
        var result: UIColor?
        //    if let hex = UInt(hexString, radix: 16) {
        //        result = UIColor.colorWithHex(hex)
        result = UIColor(hex: hex)
        //    }
        return result
    }
#endif
