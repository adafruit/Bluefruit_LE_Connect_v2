//
//  FirmwareUpdater.swift
//  Bluefruit
//
//  Created by Antonio on 27/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

struct DeviceInformationService {
    var manufacturer: String?
    var modelNumber: String?
    var firmwareRevision: String?
    var softwareRevision: String?
}

protocol FirmwareUpdaterDelegate: class {
    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceInfo: DeviceInformationService?, allReleases:[FirmwareInfo]?)
}

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
    static let kDisServiceUUID =  CBUUID.init(string: FirmwareUpdater.kDeviceInformationService)
    static let kDfuServiceUUID =  CBUUID.init(string: FirmwareUpdater.kNordicDeviceFirmwareUpdateService)
    static let kManufacturerCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kManufacturerNameCharacteristic)
    static let kModelNumberCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kModelNumberCharacteristic)
    static let kSoftwareRevisionCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kSoftwareRevisionCharacteristic)
    static let kFirmwareRevisionCharacteristicUUID =  CBUUID.init(string: FirmwareUpdater.kFirmwareRevisionCharacteristic)
    
    
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
    
    func releases(showBetaVersions: Bool) -> [BoardInfo]? {
        guard let data = UserDefaults.standard.object(forKey: FirmwareUpdater.kReleasesXml) as? Data else {
            return nil
        }
        
        let boards = ReleasesParser.parse(data: data, showBetaVersions: showBetaVersions)
        return boards
    }
    
    // MARK: - Peripheral Management
    func checkUpdatesForPeripheral(_ peripheral: BlePeripheral, delegate: FirmwareUpdaterDelegate, shouldDiscoverServices: Bool, shouldRecommendBetaReleases: Bool, versionToIgnore: String?) {
        
        if shouldDiscoverServices {
            peripheral.discover(serviceUuids: nil) { [weak self] error in
                self?.servicesDiscovered(peripheral: peripheral, delegate: delegate, versionToIgnore: versionToIgnore)
            }
        }
        else {
            servicesDiscovered(peripheral: peripheral, delegate: delegate, versionToIgnore: versionToIgnore)
        }
    }
    
    private func servicesDiscovered(peripheral: BlePeripheral, delegate: FirmwareUpdaterDelegate, versionToIgnore: String?) {
        guard let _ = peripheral.discoveredService(uuid: FirmwareUpdater.kDfuServiceUUID), let disService = peripheral.discoveredService(uuid: FirmwareUpdater.kDisServiceUUID) else {
            DLog("Updates: Peripheral has no DFU or DIS service available")
            DispatchQueue.main.async {
                delegate.onFirmwareUpdateAvailable(isUpdateAvailable: false, latestRelease: nil, deviceInfo: nil, allReleases: nil)
            }
            return
        }
        
        // Note: macOS seems to have problems discovering a specific set of characteristics, so nil is passed to discover all of them
        peripheral.discover(characteristicUuids: nil, service: disService) { [weak self] error in
            
            guard let strongSelf = self else { return }
            
            var dis = DeviceInformationService()
            let dispatchGroup = DispatchGroup()         // Wait till all the required characteristics are read to continue
            
            // Manufacturer
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kManufacturerCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { dis.manufacturer = $0 }
            // Model Number
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kModelNumberCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { dis.modelNumber = $0 }
            // Firmware Revision
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kFirmwareRevisionCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { dis.firmwareRevision = $0 }
            // Software Revision
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kSoftwareRevisionCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { dis.softwareRevision = $0 }
    
            // All read
            dispatchGroup.notify(queue: .global(), execute: { [weak strongSelf] in
                DLog("Device Info Data received")
                strongSelf?.checkUpdates(delegate: delegate, versionToIgnore: versionToIgnore)
            })
        }
        
    }
    
    
    private func readCharacteristic(uuid: CBUUID, peripheral: BlePeripheral, service: CBService, dispatchGroup: DispatchGroup, completion: @escaping ((String?) -> Void)) {
        dispatchGroup.enter()
        if let characteristic = peripheral.discoveredCharacteristic(uuid: uuid, service: service) {
            peripheral.read(from: characteristic) { (data, error) in
                defer { dispatchGroup.leave() }
                guard error == nil, let data = data, let stringValue = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }

                completion(stringValue)
            }
        }
        else {
            dispatchGroup.leave()
        }
    }
    
    
    private func checkUpdates(delegate: FirmwareUpdaterDelegate, versionToIgnore: String?) {
        var isFirmwareUpdateAvailable = false
        
        
    }
    
    
    /*
 
     guard let releases = releases else {
     DLog("Updates: releases array is empty")
     DispatchQueue.main.async {
     delegate.onFirmwareUpdateAvailable(isUpdateAvailable: false, latestRelease: nil, deviceInfo: nil, allReleases: nil)
     }
     return
     }

 */
}
