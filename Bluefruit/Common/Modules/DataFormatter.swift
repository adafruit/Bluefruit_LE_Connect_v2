//
//  DataFormatter.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit

// MARK: - UI Utils
func attributedStringFromData(_ data: Data, useHexMode: Bool, color: Color, font: Font) -> NSAttributedString? {
    var attributedString : NSAttributedString?
    
    let textAttributes: [String: AnyObject] = [NSFontAttributeName: font, NSForegroundColorAttributeName: color]
    
    if useHexMode {
        let hexValue = hexDescription(data: data)
        attributedString = NSAttributedString(string: hexValue, attributes: textAttributes)
    }
    else {
        if let value = String(data: data, encoding: .ascii) as String? {
            
            var representableValue: String
            
            if Preferences.uartShowInvisibleChars {
                representableValue = ""
                for scalar in value.unicodeScalars {
                    let isRepresentable = scalar.value>=32 && scalar.value<127
                    //DLog("\(scalar.value). isVis: \( isRepresentable ? "true":"false" )")                
                    representableValue.append(isRepresentable ? String(scalar):"�")
                }
            }
            else {
                representableValue = value
            }
            
            attributedString = NSAttributedString(string: representableValue, attributes: textAttributes)
        }
    }
    
    return attributedString
}
