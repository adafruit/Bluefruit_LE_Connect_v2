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
    static fileprivate let kDebugShowDummyCharacters = false

    //
    static let sharedInstance = LocalizationManager()

    fileprivate var localizationBundle: Bundle?

    var languageCode: String {
        didSet {
          updateBundle()
        }
    }

    init() {
        self.languageCode = "en"
        updateBundle()      // needed because didSet is not invoked from initializer
    }

    fileprivate func updateBundle() {
        localizationBundle = nil

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            localizationBundle = Bundle(path:path)
        } else {
            if let range = languageCode.range(of: "-") {

                let baseCode = String(languageCode[..<range.lowerBound])
                if let path =  Bundle.main.path(forResource: baseCode, ofType: "lproj") {
                    localizationBundle = Bundle(path:path)
                }
            }

            if localizationBundle == nil {
                DLog("Error setting languageCode: \(languageCode). Bundle does not exist")
            }
        }
    }

    func localizedString(_ key: String) -> String {
        return localizedString(key, description: nil)
    }

    func localizedString(_ key: String, description: String?) -> String {
        var result: String!

        if let string = localizationBundle?.localizedString(forKey: key, value: description, table: nil) {
            result = string
        } else {
            result = key
        }

        if LocalizationManager.kDebugShowDummyCharacters {
            result = String(repeating: "x", count: result.count)
        }

        return result
    }
}
