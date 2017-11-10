//
//  DataFormatter.swift
//  Bluefruit
//
//  Created by Antonio on 01/02/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation

// MARK: - UI Utils
func stringFromData(_ data: Data, useHexMode: Bool) -> String? {
    var result: String?

    if useHexMode {
        let hexValue = hexDescription(data: data)
        result = hexValue
    } else {
        if let value = String(data: data, encoding: .ascii) as String? {
            var representableValue: String

            if Preferences.uartShowInvisibleChars {
                representableValue = ""
                for scalar in value.unicodeScalars {
                    let isRepresentable = scalar.value>=32 && scalar.value<127
                    //DLog("\(scalar.value). isVis: \( isRepresentable ? "true":"false" )")
                    representableValue.append(isRepresentable ? String(scalar):"�")
                }
            } else {
                representableValue = value
            }

            result = representableValue
        }
    }
    return result
}

func attributedStringFromData(_ data: Data, useHexMode: Bool, color: Color, font: Font) -> NSAttributedString? {

    guard let string = stringFromData(data, useHexMode: useHexMode) else { return nil }

    let textAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: font, NSAttributedStringKey.foregroundColor: color]
    let attributedString = NSAttributedString(string: string, attributes: textAttributes)
    return attributedString
}
