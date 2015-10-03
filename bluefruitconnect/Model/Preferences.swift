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
    private static let appInSystemStatusBarKey = "AppInSystemStatusBar"
    private static let updateServerUrlKey = "UpdateServerUrl"
    private static let updateShowBetaVersionsKey = "UpdateShowBetaVersions"
    private static let uartReceivedDataColorKey = "UartReceivedDataColor"
    private static let uartSentDataColorKey = "UartSentDataColor"
    
    enum PreferencesNotifications : String {
        case DidUpdatePreferences = "didUpdatePreferences"          // Note: used on some objective-c code, so when changed, update it
    }

    static var appInSystemStatusBar : Bool {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.boolForKey(Preferences.appInSystemStatusBarKey)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(newValue, forKey: Preferences.appInSystemStatusBarKey)
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
        }
    }
    
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
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
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
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
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
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
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
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
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

