//
//  LocalizationManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 19/11/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

class LocalizationManager {
    // Config
    static private let kDebugShowDummyCharacters = false
    
    //
    static let sharedInstance = LocalizationManager()

    private var localizationBundle : Bundle?
    
    var languageCode : String {

        didSet {
          updateBundle()
        }
    }

    init() {
        self.languageCode = "en"
        updateBundle()      // needed because didSet is not invoked from initializer
        
    }

    private func updateBundle() {
        localizationBundle = nil
        
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            localizationBundle = Bundle(path:path)
        }
        else {
            if let range: Range<String.Index> = languageCode.range(of: "-") {
                
                let baseCode = String(languageCode[..<range.lowerBound]) //.substring(to: range.lowerBound)
                if let path =  Bundle.main.path(forResource: baseCode, ofType: "lproj") {
                    localizationBundle = Bundle(path:path)
                }
            }

            if (localizationBundle == nil) {
                DLog(message: "Error setting languageCode: \(languageCode). Bundle does not exist")
            }
        }
    }
    
    func localizedString(key : String) -> String {
        return localizedString(key: key, description: nil)
    }
    
    func localizedString(key : String, description : String?) -> String {
        var result : String!
        
        if let string = localizationBundle?.localizedString(forKey: key, value: description, table: nil) {
            result = string
        } else {
            result = key
        }
        
        if LocalizationManager.kDebugShowDummyCharacters {
            result = String(repeating: "x", count: result.characters.count)
        }
        
        return result
    }
}
