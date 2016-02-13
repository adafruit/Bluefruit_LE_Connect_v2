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

    private var localizationBundle : NSBundle?
    
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
        
        if let path = NSBundle.mainBundle().pathForResource(languageCode, ofType: "lproj") {
            localizationBundle = NSBundle(path:path)
        }
        else {
            if let range: Range<String.Index> = languageCode.rangeOfString("-") {
                
                let baseCode = languageCode.substringToIndex(range.startIndex)
                if let path =  NSBundle.mainBundle().pathForResource(baseCode, ofType: "lproj") {
                    localizationBundle = NSBundle(path:path)
                }
            }

            if (localizationBundle == nil) {
                DLog("Error setting languageCode: \(languageCode). Bundle does not exist")
            }
        }
    }
    
    func localizedString(key : String) -> String {
        return localizedString(key, description: nil)
    }
    
    func localizedString(key : String, description : String?) -> String {
        var result : String!
        
        if let string = localizationBundle?.localizedStringForKey(key, value: description, table: nil) {
            result = string
        } else {
            result = key
        }
        
        if LocalizationManager.kDebugShowDummyCharacters {
            result =  String(count: result.characters.count, repeatedValue: ("x" as Character))
        }
        
        return result
    }
}