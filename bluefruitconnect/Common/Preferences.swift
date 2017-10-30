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

@objc class Preferences: NSObject {                // will be used from objective-c so make it inherit from NSObject
    
    // Note: if these contanst change, update DefaultPreferences.plist
    private static let appInSystemStatusBarKey = "AppInSystemStatusBar"
    
    private static let scanFilterIsPanelOpenKey = "ScanFilterIsPanelOpen"
    private static let scanFilterNameKey = "ScanFilterName"
    private static let scanFilterIsNameExactKey = "ScanFilterIsNameExact"
    private static let scanFilterIsNameCaseInsensitiveKey = "ScanFilterIsNameCaseInsensitive"
    private static let scanFilterRssiValueKey = "ScanFilterRssiValue"
    private static let scanFilterIsUnnamedEnabledKey = "ScanFilterIsUnnamedEnabled"
    private static let scanFilterIsOnlyWithUartEnabledKey = "ScanFilterIsOnlyWithUartEnabled"
    
    private static let updateServerUrlKey = "UpdateServerUrl"
    private static let updateShowBetaVersionsKey = "UpdateShowBetaVersions"
    private static let updateIgnoredVersionKey = "UpdateIgnoredVersion"

    private static let infoRefreshOnLoadKey = "InfoRefreshOnLoad"

    private static let uartReceivedDataColorKey = "UartReceivedDataColor"
    private static let uartSentDataColorKey = "UartSentDataColor"
    private static let uartIsDisplayModeTimestampKey = "UartIsDisplayModeTimestamp"
    private static let uartIsInHexModeKey = "UartIsInHexMode"
    private static let uartIsEchoEnabledKey = "UartIsEchoEnabled"
    private static let uartIsAutomaticEolEnabledKey = "UartIsAutomaticEolEnabled"
    private static let uartShowInvisibleCharsKey = "UartShowInvisibleChars"
    
    private static let neopixelIsSketchTooltipEnabledKey = "NeopixelIsSketchTooltipEnabledKey"
    
//    enum PreferencesNotifications: String {
//        case DidUpdatePreferences = "didUpdatePreferences"          // Note: used on some objective-c code, so when changed, update it
//    }
    
    // MARK: - General
    static var appInSystemStatusBar: Bool {
        get {
            return getBoolPreference(key: Preferences.appInSystemStatusBarKey)
        }
        set {
            setBoolPreference(key: Preferences.appInSystemStatusBarKey, newValue: newValue)
        }
    }
    
    // MARK: - Scanning Filters
    static var scanFilterIsPanelOpen: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsPanelOpenKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsPanelOpenKey, newValue: newValue)
        }
    }

    static var scanFilterName: String? {
        get {
            let defaults = UserDefaults.standard
            return defaults.string(forKey: Preferences.scanFilterNameKey)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: Preferences.scanFilterNameKey)
        }
    }
    
    static var scanFilterIsNameExact: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsNameExactKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsNameExactKey, newValue: newValue)
        }
    }

    static var scanFilterIsNameCaseInsensitive: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsNameCaseInsensitiveKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsNameCaseInsensitiveKey, newValue: newValue)
        }
    }

    static var scanFilterRssiValue: Int? {
        get {
            let defaults = UserDefaults.standard
            let rssiValue = defaults.integer(forKey: Preferences.scanFilterRssiValueKey)
            return rssiValue >= 0 ? rssiValue:nil
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue ?? -1, forKey: Preferences.scanFilterRssiValueKey)
        }
    }
    
    static var scanFilterIsUnnamedEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsUnnamedEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsUnnamedEnabledKey, newValue: newValue)
        }
    }
    
    static var scanFilterIsOnlyWithUartEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.scanFilterIsOnlyWithUartEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.scanFilterIsOnlyWithUartEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Firmware Updates
    static var updateServerUrl: NSURL? {
        get {
            let defaults = UserDefaults.standard
            let urlString = defaults.string(forKey: Preferences.updateServerUrlKey)
            if let urlString = urlString {
                return NSURL(string: urlString)
            }
            else {
                return nil
            }
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue?.absoluteString, forKey: Preferences.updateServerUrlKey)
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil);
        }
    }
    
    static var showBetaVersions: Bool {
        get {
            return getBoolPreference(key: Preferences.updateShowBetaVersionsKey)
        }
        set {
            setBoolPreference(key: Preferences.updateShowBetaVersionsKey, newValue: newValue)
        }
    }
    
    @objc static var softwareUpdateIgnoredVersion: String? {
        get {
            let defaults = UserDefaults.standard
            return defaults.string(forKey: Preferences.updateIgnoredVersionKey)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: Preferences.updateIgnoredVersionKey)
        }
    }
    
    // MARK: - Info
    static var infoIsRefreshOnLoadEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.infoRefreshOnLoadKey)
        }
        set {
            setBoolPreference(key: Preferences.infoRefreshOnLoadKey, newValue: newValue)
        }
    }
    
    
    // MARK: - Uart
    static var uartReceveivedDataColor: Color {
        get {
            let defaults = UserDefaults.standard
            let hexColorString = defaults.string(forKey: Preferences.uartReceivedDataColorKey)
            return Color(css: hexColorString)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.hexString(), forKey: Preferences.uartReceivedDataColorKey)
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil);
        }
    }
    
    static var uartSentDataColor: Color {
        get {
            let defaults = UserDefaults.standard
            let hexColorString = defaults.string(forKey: Preferences.uartSentDataColorKey)
            return Color(css: hexColorString)
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue.hexString(), forKey: Preferences.uartSentDataColorKey)
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil);
        }
    }
    
    static var uartShowInvisibleChars: Bool {
        get {
            return getBoolPreference(key: Preferences.uartShowInvisibleCharsKey)
        }
        set {
            setBoolPreference(key: Preferences.uartShowInvisibleCharsKey, newValue: newValue)
        }
    }
    
    
    static var uartIsDisplayModeTimestamp: Bool {
        get {
            return getBoolPreference(key: Preferences.uartIsDisplayModeTimestampKey)
        }
        set {
            setBoolPreference(key: Preferences.uartIsDisplayModeTimestampKey, newValue: newValue)
        }
    }
    
    static var uartIsInHexMode: Bool {
        get {
            return getBoolPreference(key: Preferences.uartIsInHexModeKey)
        }
        set {
            setBoolPreference(key: Preferences.uartIsInHexModeKey, newValue: newValue)
        }
    }
    
    static var uartIsEchoEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.uartIsEchoEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.uartIsEchoEnabledKey, newValue: newValue)
        }
    }
    
    static var uartIsAutomaticEolEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.uartIsAutomaticEolEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.uartIsAutomaticEolEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Neopixels
    static var neopixelIsSketchTooltipEnabled: Bool {
        get {
            return getBoolPreference(key: Preferences.neopixelIsSketchTooltipEnabledKey)
        }
        set {
            setBoolPreference(key: Preferences.neopixelIsSketchTooltipEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Common
    static func getBoolPreference(key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: key)
    }
    
    static func setBoolPreference(key: String, newValue: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(newValue, forKey: key)
        NotificationCenter.default.post(name: .didUpdatePreferences, object: nil);
    }
    
    // MARK: - Defaults
    static func registerDefaults() {
        let path = Bundle.main.path(forResource: "DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String : AnyObject]
        
        UserDefaults.standard.register(defaults: defaultPrefs)
    }
    
    static func resetDefaults() {
        let appDomain = Bundle.main.bundleIdentifier!
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: appDomain)
    }
}

extension Notification.Name {
    static let didUpdatePreferences = Notification.Name("didUpdatePreferences")          // Note: used on some objective-c code, so when changed, update it
}
