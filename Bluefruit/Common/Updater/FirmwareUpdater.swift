//
//  FirmwareUpdater.swift
//  Bluefruit
//
//  Created by Antonio on 27/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class FirmwareUpdater {
    // Config
    fileprivate static let kReleasesXml = "updatemanager_releasesxml"
    
    // Constants
    static let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"
    static let kDeviceInformationService = "180A"
    static let kModelNumberCharacteristic = "00002A24-0000-1000-8000-00805F9B34FB"
    static let kManufacturerNameCharacteristic = "00002A29-0000-1000-8000-00805F9B34FB"
    static let kSoftwareRevisionCharacteristic = "00002A28-0000-1000-8000-00805F9B34FB"
    static let kFirmwareRevisionCharacteristic = "00002A26-0000-1000-8000-00805F9B34FB"

    // Data
    static let disServiceUUID =  CBUUID.init(string: FirmwareUpdater.kDeviceInformationService)
    static let dfuServiceUUID =  CBUUID.init(string: FirmwareUpdater.kNordicDeviceFirmwareUpdateService)
    static let manufacturerCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kManufacturerNameCharacteristic)
    static let modelNumberCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kModelNumberCharacteristic)
    static let softwareRevisionCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kSoftwareRevisionCharacteristic)
    static let firmwareRevisionCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kFirmwareRevisionCharacteristic)
    
    func releases(showBetaVersions: Bool) -> [BoardInfo]? {
        guard let data = UserDefaults.standard.object(forKey: FirmwareUpdater.kReleasesXml) as? Data else {
            return nil
        }
    
        let boards = ReleasesParser.parse(data: data, showBetaVersions: showBetaVersions)
        return boards
    }
    
    static func refreshSoftwareUpdatesDatabase(url: URL?, completion: ((Bool) -> Void)?) {
        guard let url = url else { return }
        
        downloadData(from: url) { data in
            // Save to user deafults
            UserDefaults.standard.set(data, forKey: FirmwareUpdater.kReleasesXml)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: .didUpdatePreferences, object: nil)
            
            completion?(data != nil)
        }
    }
}
