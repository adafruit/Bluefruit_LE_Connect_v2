//
//  Preferences.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import AppKit

@objc class Preferences : NSObject {                // will be used from objective-c so make it inherit from NSObject
    private static let updateServerUrlKey = "UpdateServerUrl"
    private static let updateShowBetaVersionsKey = "UpdateShowBetaVersions"
    private static let uartReceivedDataColorKey = "UartReceivedDataColor"
    private static let uartSentDataColorKey = "UartSentDataColor"
    
    static var updateServerUrl : NSURL? {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            let urlString = defaults.stringForKey(Preferences.updateServerUrlKey)
            if let urlString = urlString {
                return NSURL(string: urlString)
            }
            else {
                return nil
            }
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue?.absoluteString, forKey: Preferences.updateServerUrlKey)
        }
    }
    
    static var showBetaVersions : Bool {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.boolForKey(Preferences.updateShowBetaVersionsKey)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(newValue, forKey: Preferences.updateShowBetaVersionsKey)
        }
    }
    
    static var uartReceveivedDataColor : NSColor {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            let hexColorString = defaults.stringForKey(Preferences.uartReceivedDataColorKey)
            return NSColor(fromHexadecimalValue: hexColorString)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue.hexadecimalValue(), forKey: Preferences.uartReceivedDataColorKey)
        }
    }
    
    static var uartSentDataColor : NSColor {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            let hexColorString = defaults.stringForKey(Preferences.uartSentDataColorKey) 
            return NSColor(fromHexadecimalValue: hexColorString)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue.hexadecimalValue(), forKey: Preferences.uartSentDataColorKey)
        }
    }
    
    static func registerDefaults() {
        let path = NSBundle.mainBundle().pathForResource("DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String : AnyObject]
        
        NSUserDefaults.standardUserDefaults().registerDefaults(defaultPrefs)
    }
    
    static func resetDefaults() {
        let appDomain = NSBundle.mainBundle().bundleIdentifier!
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.removePersistentDomainForName(appDomain)
    }
}

