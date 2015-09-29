//
//  Preferences.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation


@objc class Preferences : NSObject {                // will be used from objective-c so make it inherit from NSObject
    private static let updateServerUrlUserDefaultsKey = "UpdateServerUrl"
    
    static var updateServerUrl : NSURL? {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            let urlString = defaults.stringForKey(Preferences.updateServerUrlUserDefaultsKey)
            var url : NSURL?
            if let urlString = urlString {
                url = NSURL(string: urlString)
            }
            DLog("get updateServerUrl: \(url)")
            return url
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue?.absoluteString, forKey: Preferences.updateServerUrlUserDefaultsKey)
        }
    }
    
    static func registerDefaults() {
        let path = NSBundle.mainBundle().pathForResource("DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String : AnyObject]
        
        DLog("defaults: \(defaultPrefs[Preferences.updateServerUrlUserDefaultsKey])");
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
        
        
    }
    
    static func resetDefaults() {
        let appDomain = NSBundle.mainBundle().bundleIdentifier!
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.removePersistentDomainForName(appDomain)
    }
}

