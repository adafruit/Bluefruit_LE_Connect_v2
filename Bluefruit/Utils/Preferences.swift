//
//  Preferences.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 29/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

import UIKit
import UIColor_Hex

class Preferences {
    
    // MARK: - UserDefault Keys
    // Note: if these contanst change, update DefaultPreferences.plist
    private static let scanFilterIsPanelOpenKey = "ScanFilterIsPanelOpen"
    private static let scanFilterNameKey = "ScanFilterName"
    private static let scanFilterIsNameExactKey = "ScanFilterIsNameExact"
    private static let scanFilterIsNameCaseInsensitiveKey = "ScanFilterIsNameCaseInsensitive"
    private static let scanFilterRssiValueKey = "ScanFilterRssiValue"
    private static let scanFilterIsUnnamedEnabledKey = "ScanFilterIsUnnamedEnabled"
    private static let scanFilterIsOnlyWithUartEnabledKey = "ScanFilterIsOnlyWithUartEnabled"
    
    // Firmware Updates
    private static let updateServerUrlKey = "UpdateServerUrl"
    private static let updateShowBetaVersionsKey = "UpdateShowBetaVersions"
    private static let updateIgnoredVersionKey = "UpdateIgnoredVersion"
    
    // Info
    private static let infoRefreshOnLoadKey = "InfoRefreshOnLoad"
    
    // Uart
    private static let uartDisplayModeKey = "UartDisplayMode"
    private static let uartIsInHexModeKey = "UartIsInHexMode"
    private static let uartIsEchoEnabledKey = "UartIsEchoEnabled"
    private static let uartIsAutomaticEolEnabledKey = "UartIsAutomaticEolEnabled"
    private static let uartShowInvisibleCharsKey = "UartShowInvisibleChars"
    private static let uartEolCharactersIdKey = "UartEolCharactersId"
    
    // Neopixel
    private static let neopixelIsSketchTooltipEnabledKey = "NeopixelIsSketchTooltipEnabledKey"
    private static let neopixelIsUsingStandardBoardsKey = "NeopixelIsUsingStandardBoardsKey"
    private static let neopixelStandardBoardIndexKey = "NeopixelStandardBoardIndexKey"
    private static let neopixelLineBoardLengthKey = "NeopixelLineBoardLengthKey"
    private static let neopixelComponentsKey = "NeopixelComponentsKey"
    private static let neopixelIsUsing400KhzKey = "NeopixelIsUsing400KhzKey"
    
    // Calibration
    private static let magnetometerTypeKey = "MagnetometerType"
    private static let accelerometerTypeKey = "AccelerometerType"
    private static let gyroscopeTypeKey = "GyroscopeType"
    
    private static let magnetometerGapTargetKey = "MagnetometerGapTarget"
    private static let magnetometerWobbleTargetKey = "MagnetometerWobbleTarget"
    private static let magnetometerVarianceTargetKey = "MagnetometerVarianceTarget"
    private static let magnetometerFitErrorTargetKey = "MagnetometerFitErrorTarget"
    
    private static let gyroReadingsCountKey = "GyroReadingsCount"
    private static let gyroNoiseLevelKey = "GyroNoiseLevel"
    private static let gyroUnitIdKey = "GyroUnitId"
    
    private static let visualizationXAxisInvertedKey = "VisualizationXAxisInverted"
    private static let visualizationYAxisInvertedKey = "VisualizationYAxisInverted"
    private static let visualizationZAxisInvertedKey = "VisualizationZAxisInverted"
    private static let visualizationXAxisFlippedKey = "VisualizationXAxisFlipped"
    private static let visualizationYAxisFlippedKey = "VisualizationYAxisFlipped"
    private static let visualizationZAxisFlippedKey = "VisualizationZAxisFlipped"
    private static let visualizationSwitchYZKey = "VisualizationSwitchYZ"
    
    private static let imageTransferResolutionKey = "ImageTransferResolution"
    private static let imageTransferInterleavedWithoutResponseCountKey = "ImageTransferInterleavedWithoutResponseCountKey"
    private static let imageTransferIsColorSpace24BitKey = "IsColorSpace24BitKey"
    private static let imageTransferIsEInkModeEnabledKey = "IsEInkModeEnabled"
    
    
    // MARK: - Scanning Filters
    static var scanFilterIsPanelOpen: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsPanelOpenKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsPanelOpenKey, newValue: newValue)
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
            return getBoolPreference(Preferences.scanFilterIsNameExactKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsNameExactKey, newValue: newValue)
        }
    }
    
    static var scanFilterIsNameCaseInsensitive: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsNameCaseInsensitiveKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsNameCaseInsensitiveKey, newValue: newValue)
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
            return getBoolPreference(Preferences.scanFilterIsUnnamedEnabledKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsUnnamedEnabledKey, newValue: newValue)
        }
    }
    
    static var scanFilterIsOnlyWithUartEnabled: Bool {
        get {
            return getBoolPreference(Preferences.scanFilterIsOnlyWithUartEnabledKey)
        }
        set {
            setBoolPreference(Preferences.scanFilterIsOnlyWithUartEnabledKey, newValue: newValue)
        }
    }
    
    // MARK: - Firmware Updates
    static var updateServerUrl: URL? {
        get {
            let defaults = UserDefaults.standard
            let urlString = defaults.string(forKey: Preferences.updateServerUrlKey)
            if let urlString = urlString {
                return URL(string: urlString)
            } else {
                return nil
            }
        }
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue?.absoluteString, forKey: Preferences.updateServerUrlKey)
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil)
        }
    }
    
    static var showBetaVersions: Bool {
        get {
            return getBoolPreference(Preferences.updateShowBetaVersionsKey)
        }
        set {
            setBoolPreference(Preferences.updateShowBetaVersionsKey, newValue: newValue)
        }
    }
    
    static var softwareUpdateIgnoredVersion: String? {
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
            return getBoolPreference(Preferences.infoRefreshOnLoadKey)
        }
        set {
            setBoolPreference(Preferences.infoRefreshOnLoadKey, newValue: newValue)
        }
    }
    
    // MARK: - Uart
    static var uartShowInvisibleChars: Bool {
        get {
            return getBoolPreference(Preferences.uartShowInvisibleCharsKey)
        }
        set {
            setBoolPreference(Preferences.uartShowInvisibleCharsKey, newValue: newValue)
        }
    }
    
    
    enum UartDisplayMode: Int {
        case timeStamp = 0
        case text = 1
        case terminal = 2
    }
    
    static var uartDisplayMode: UartDisplayMode {
        get {
            let displayModeRaw = UserDefaults.standard.integer(forKey: Preferences.uartDisplayModeKey)
            return UartDisplayMode(rawValue: displayModeRaw) ?? .timeStamp
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Preferences.uartDisplayModeKey)
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil)
        }
    }
    
    static var uartIsInHexMode: Bool {
        get {
            return getBoolPreference(Preferences.uartIsInHexModeKey)
        }
        set {
            setBoolPreference(Preferences.uartIsInHexModeKey, newValue: newValue)
        }
    }
    
    static var uartIsEchoEnabled: Bool {
        get {
            return getBoolPreference(Preferences.uartIsEchoEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsEchoEnabledKey, newValue: newValue)
        }
    }
    
    static var uartIsAutomaticEolEnabled: Bool {
        get {
            return getBoolPreference(Preferences.uartIsAutomaticEolEnabledKey)
        }
        set {
            setBoolPreference(Preferences.uartIsAutomaticEolEnabledKey, newValue: newValue)
        }
    }
    
    static var uartEolCharactersId: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.uartEolCharactersIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.uartEolCharactersIdKey)
        }
    }
    
    static var uartEolCharacters: String {
        var uartEolCharacters: String
        switch Preferences.uartEolCharactersId {
        case 1: uartEolCharacters = "\r"
        case 2: uartEolCharacters = "\n\r"
        case 3: uartEolCharacters = "\r\n"
        default: uartEolCharacters = "\n"
        }
        return uartEolCharacters
    }
    
    // MARK: - Neopixels
    static var neopixelIsSketchTooltipEnabled: Bool {
        get {
            return getBoolPreference(Preferences.neopixelIsSketchTooltipEnabledKey)
        }
        set {
            setBoolPreference(Preferences.neopixelIsSketchTooltipEnabledKey, newValue: newValue)
        }
    }
    
    static var neopixelIsUsingStandardBoards: Bool {
        get {
            return getBoolPreference(Preferences.neopixelIsUsingStandardBoardsKey)
        }
        set {
            setBoolPreference(Preferences.neopixelIsUsingStandardBoardsKey, newValue: newValue)
        }
    }
    
    static var neopixelStandardBoardIndex: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.neopixelStandardBoardIndexKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.neopixelStandardBoardIndexKey)
        }
    }
    
    static var neopixelLineBoardLength: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.neopixelLineBoardLengthKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.neopixelLineBoardLengthKey)
        }
    }
    
    
    static var neopixelComponents: UInt8 {
        get {
            return UInt8(UserDefaults.standard.integer(forKey: Preferences.neopixelComponentsKey))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.neopixelComponentsKey)
        }
    }
    
    static var neopixelIsUsing400Khz: Bool {
        get {
            return getBoolPreference(Preferences.neopixelIsUsing400KhzKey)
        }
        set {
            setBoolPreference(Preferences.neopixelIsUsing400KhzKey, newValue: newValue)
        }
    }
    
    
    // MARK: - Sensor Config
    static var magnetometerType: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.magnetometerTypeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.magnetometerTypeKey)
        }
    }
    
    static var accelerometerType: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.accelerometerTypeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.accelerometerTypeKey)
        }
    }
    
    static var gyroscopeType: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.gyroscopeTypeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.gyroscopeTypeKey)
        }
    }
    
    // MARK: - Magnetometer Calibration
    static var magnetometerGapTarget: Float {
        get {
            return UserDefaults.standard.float(forKey: Preferences.magnetometerGapTargetKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.magnetometerGapTargetKey)
        }
    }
    
    static var magnetometerWobbleTarget: Float {
        get {
            return UserDefaults.standard.float(forKey: Preferences.magnetometerWobbleTargetKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.magnetometerWobbleTargetKey)
        }
    }
    
    static var magnetometerVarianceTarget: Float {
        get {
            return UserDefaults.standard.float(forKey: Preferences.magnetometerVarianceTargetKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.magnetometerVarianceTargetKey)
        }
    }
    
    static var magnetometerFitErrorTarget: Float {
        get {
            return UserDefaults.standard.float(forKey: Preferences.magnetometerFitErrorTargetKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.magnetometerFitErrorTargetKey)
        }
    }
    
    // MARK: - Gyroscope Calibration
    
    static var gyroReadingsCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.gyroReadingsCountKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.gyroReadingsCountKey)
        }
    }
    
    static var gyroNoiseLevel: Float {
        get {
            return UserDefaults.standard.float(forKey: Preferences.gyroNoiseLevelKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.gyroNoiseLevelKey)
        }
    }
    
    static var gyroUnitId: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.gyroUnitIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.gyroUnitIdKey)
        }
    }
    
    // MARK: - Visualization
    
    static var visualizationXAxisInverted: Bool {
        get {
            return getBoolPreference(Preferences.visualizationXAxisInvertedKey)
        }
        set {
            setBoolPreference(Preferences.visualizationXAxisInvertedKey, newValue: newValue)
        }
    }
    
    static var visualizationYAxisInverted: Bool {
        get {
            return getBoolPreference(Preferences.visualizationYAxisInvertedKey)
        }
        set {
            setBoolPreference( Preferences.visualizationYAxisInvertedKey, newValue: newValue)
        }
    }
    
    static var visualizationZAxisInverted: Bool {
        get {
            return getBoolPreference(Preferences.visualizationZAxisInvertedKey)
        }
        set {
            setBoolPreference(Preferences.visualizationZAxisInvertedKey, newValue: newValue)
        }
    }
    
    static var visualizationXAxisFlipped: Bool {
        get {
            return getBoolPreference(Preferences.visualizationXAxisFlippedKey)
        }
        set {
            setBoolPreference(Preferences.visualizationXAxisFlippedKey, newValue: newValue)
        }
    }
    
    static var visualizationYAxisFlipped: Bool {
        get {
            return getBoolPreference(Preferences.visualizationYAxisFlippedKey)
        }
        set {
            setBoolPreference(Preferences.visualizationYAxisFlippedKey, newValue: newValue)
        }
    }
    
    static var visualizationZAxisFlipped: Bool {
        get {
            return getBoolPreference(Preferences.visualizationZAxisFlippedKey)
        }
        set {
            setBoolPreference(Preferences.visualizationZAxisFlippedKey, newValue: newValue)
        }
    }
    
    static var visualizationSwitchYZ: Bool {
        get {
            return getBoolPreference(Preferences.visualizationSwitchYZKey)
        }
        set {
            setBoolPreference(Preferences.visualizationSwitchYZKey, newValue: newValue)
        }
    }
    
    // MARK: - Image Transfer
    static var imageTransferResolution: CGSize? {
        get {
            let defaults = UserDefaults.standard
            
            var value = CGSize.zero
            if let valueString = defaults.string(forKey: Preferences.imageTransferResolutionKey) {
                value = NSCoder.cgSize(for: valueString)
            }
            return value != .zero ? value:nil
        }
        set {
            UserDefaults.standard.set(NSCoder.string(for: newValue ?? CGSize.zero), forKey: Preferences.imageTransferResolutionKey)
        }
    }
    
    static var imageTransferInterleavedWithoutResponseCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: Preferences.imageTransferInterleavedWithoutResponseCountKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Preferences.imageTransferInterleavedWithoutResponseCountKey)
        }
    }
    
    static var imageTransferIsColorSpace24Bit: Bool {
        get {
            return getBoolPreference(Preferences.imageTransferIsColorSpace24BitKey)
        }
        set {
            setBoolPreference(Preferences.imageTransferIsColorSpace24BitKey, newValue: newValue)
        }
    }
    
    static var imageTransferIsEInkModeEnabled: Bool {
        get {
            return getBoolPreference(Preferences.imageTransferIsEInkModeEnabledKey)
        }
        set {
            setBoolPreference(Preferences.imageTransferIsEInkModeEnabledKey, newValue: newValue)
        }
    }
    
    
    // MARK: - Common
    static func getBoolPreference(_ key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    static func setBoolPreference(_ key: String, newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: key)
        NotificationCenter.default.post(name: .didUpdatePreferences, object: nil)
    }
    
    // MARK: - Defaults
    static func registerDefaults() {
        let path = Bundle.main.path(forResource: "DefaultPreferences", ofType: "plist")!
        let defaultPrefs = NSDictionary(contentsOfFile: path) as! [String: AnyObject]
        
        UserDefaults.standard.register(defaults: defaultPrefs)
    }
    
    static func resetDefaults() {
        let appDomain = Bundle.main.bundleIdentifier!
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: appDomain)
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    
    static let  didUpdatePreferences = Notification.Name(kPrefix+".didUpdatePreferences")
}
