//
//  HexUtils.swift
//  Bluefruit
//
//  Created by Antonio García on 15/10/16.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

struct HexUtils {
    static func hexDescription(data: Data, prefix: String = "", postfix: String = " ") -> String {
        return data.reduce("") {$0 + String(format: "%@%02X%@", prefix, $1, postfix)}
    }
    
    static func hexDescription(bytes: [UInt8], prefix: String = "", postfix: String = " ") -> String {
        return bytes.reduce("") {$0 + String(format: "%@%02X%@", prefix, $1, postfix)}
    }
    
    static func decimalDescription(data: Data, prefix: String = "", postfix: String = " ") -> String {
        return data.reduce("") {$0 + String(format: "%@%ld%@", prefix, $1, postfix)}
    }
}
