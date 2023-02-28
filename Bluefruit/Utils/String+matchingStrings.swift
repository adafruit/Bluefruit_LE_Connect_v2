//
//  String+matchingStrings.swift
//  Bluefruit
//
//  Created by Antonio García on 13/2/23.
//  Copyright © 2023 Adafruit. All rights reserved.
//

import Foundation

extension String {
    
    /*
     Returns a list of matches. Each match contains a list with the matched text and internal parts (with ranges)
     */
    func matchingStrings(regex: String) -> [[(String, NSRange)]] {
        let nsString = self as NSString
        return matchingStrings(regex: regex, range: NSMakeRange(0, nsString.length))
    }
    
    func matchingStrings(regex: String, range: NSRange) -> [[(String, NSRange)]] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: []) else { return [] }
        let nsString = self as NSString
        let results  = regex.matches(in: self, options: [], range: range)
        return results.map { result in
            (0..<result.numberOfRanges).map {
                let range = result.range(at: $0)
                return range.location != NSNotFound ? (nsString.substring(with: range), range) : ("", range)
            }
        }
    }
}
