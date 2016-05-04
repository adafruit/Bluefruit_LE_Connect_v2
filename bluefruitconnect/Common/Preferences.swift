//
//  Preferences.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

#if os(OSX)
    import AppKit
#else       // iOS, tvOS
    import UIKit
    import UIColor_Hex
#endif

@objc class Preferences : NSObject {                // will be used from objective-c so make it inherit from NSObject
    
    // Note: if these contanst change, update DefaultPreferences.plist
    private static let appInSystemStatusBarKey = "AppInSystemStatusBar"
    private static let updateServerUrlKey = "UpdateServerUrl"
    private static let updateShowBetaVersionsKey = "UpdateShowBetaVersions"

    private static let infoRefreshOnLoadKey = "InfoRefreshOnLoad"
    
    private static let uartReceivedDataColorKey = "UartReceivedDataColor"
    private static let uartSentDataColorKey = "UartSentDataColor"
    private static let uartIsDisplayModeTimestampKey = "UartIsDisplayModeTimestamp"
    private static let uartIsInHexModeKey = "UartIsInHexMode"
    private static let uartIsEchoEnabledKey = "UartIsEchoEnabled"
    private static let uartIsAutomaticEolEnabledKey = "UartIsAutomaticEolEnabled"
    private static let neopixelIsSketchTooltipEnabledKey = "NeopixelIsSketchTooltipEnabledKey"
    
    enum PreferencesNotifications : String {
        case DidUpdatePreferences = "didUpdatePreferences"          // Note: used on some objective-c code, so when changed, update it
    }

    // MARK: - General
    static var appInSystemStatusBar : Bool {
        get {
            return getBoolPreference(Preferences.appInSystemStatusBarKey)
        }
        set {
            setBoolPreference(Preferences.appInSystemStatusBarKey, newValue: newValue)
        }
    }
    
    // MARK: - Firmware Updates
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
            return getBoolPreference(Preferences.updateShowBetaVersionsKey)
        }
        set {
            setBoolPreference(Preferences.updateShowBetaVersionsKey, newValue: newValue)
        }
    }
    
    // MARK: - Info
    static var infoIsRefreshOnLoadEnabled : Bool {
        get {
        return getBoolPreference(Preferences.infoRefreshOnLoadKey)
        }
        set {
            setBoolPreference(Preferences.infoRefreshOnLoadKey, newValue: newValue)
        }
    }

    
    // MARK: - Uart
//    #if os(OSX)
    static var uartReceveivedDataColor : Color {
        get {
        let defaults = NSUserDefaults.standardUserDefaults()
        let hexColorString = defaults.stringForKey(Preferences.uartReceivedDataColorKey)
        return Color(CSS: hexColorString)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue.hexString(), forKey: Preferences.uartReceivedDataColorKey)
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
        }
    }
    
    static var uartSentDataColor : Color {
        get {
        let defaults = NSUserDefaults.standardUserDefaults()
        let hexColorString = defaults.stringForKey(Preferences.uartSentDataColorKey)
        return Color(CSS: hexColorString)
        }
        set {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setObject(newValue.hexString(), forKey: Preferences.uartSentDataColorKey)
            NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
        }
    }
//    #endif
    
    static var uartIsDisplayModeTimestamp : Bool {
        get {
            return getBoolPreference(Preferences.uartIsDisplayModeTimestampKey)
        }
        set {
            setBoolPreference(Preferences.uartIsDisplayModeTimestampKey, newValue: newValue)
        }
    }

    static var uartIsInHexMode : Bool {
        get {
        return getBoolPreference(Preferences.uartIsInHexModeKey)
        }
        set {
            setBoolPreference(Preferences.uartIsInHexModeKey, newValue: newValue)
        }
    }
    
    static var uartIsEchoEnabled : Bool {
        get {
        return getBoolPreference(Preferences.uartIsEchoEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsEchoEnabledKey, newValue: newValue)
        }
    }

    static var uartIsAutomaticEolEnabled : Bool {
        get {
        return getBoolPreference(Preferences.uartIsAutomaticEolEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsAutomaticEolEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Neopixels
    static var neopixelIsSketchTooltipEnabled : Bool {
        get {
            return getBoolPreference(Preferences.neopixelIsSketchTooltipEnabledKey)
        }
        set {
            setBoolPreference(Preferences.neopixelIsSketchTooltipEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Common
    static func getBoolPreference(key: String) -> Bool {
        let defaults = NSUserDefaults.standardUserDefaults()
        return defaults.boolForKey(key)
    }
    
    static func setBoolPreference(key: String, newValue: Bool) {
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(newValue, forKey: key)
        NSNotificationCenter.defaultCenter().postNotificationName(PreferencesNotifications.DidUpdatePreferences.rawValue, object: nil);
        
    }
    
    // MARK: - Defaults
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

