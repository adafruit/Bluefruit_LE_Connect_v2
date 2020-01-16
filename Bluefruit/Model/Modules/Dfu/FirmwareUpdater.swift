//
//  FirmwareUpdater.swift
//  Bluefruit
//
//  Created by Antonio on 27/01/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

struct DeviceDfuInfo {
    // Config
    static let kDefaultBootloaderVersion = "0.0"

    // Data
    var manufacturer: String?
    var modelNumber: String?
    var firmwareRevision: String?
    var softwareRevision: String?

    var bootloaderVersion: String? {
        get {
            var result = DeviceDfuInfo.kDefaultBootloaderVersion
            if let firmwareRevision = firmwareRevision, let versionSeparatorUpperBound = firmwareRevision.range(of: ", ")?.upperBound {
                //let bootloaderVersion = firmwareRevision.substring(from: versionSeparatorUpperBound)
                let bootloaderVersion = String(firmwareRevision[versionSeparatorUpperBound...])
                result = bootloaderVersion
            }
            return result
        }
    }

    var hasDefaultBootloaderVersion: Bool {
        get {
            return bootloaderVersion == DeviceDfuInfo.kDefaultBootloaderVersion
        }
    }
}

protocol FirmwareUpdaterDelegate: class {       // TODO: remove delegate and add a completion handler
    func onFirmwareUpdateAvailable(isUpdateAvailable: Bool, latestRelease: FirmwareInfo?, deviceDfuInfo: DeviceDfuInfo?)
}

class FirmwareUpdater {
    // Config
    fileprivate static let kManufacturer = "Adafruit Industries"
    fileprivate static let kReleasesXml = "updatemanager_releasesxml"

    // Constants
    static let kNordicDeviceFirmwareUpdateService = "00001530-1212-EFDE-1523-785FEABCD123"
    static let kDeviceInformationService = "180A"
    static let kModelNumberCharacteristic = "00002A24-0000-1000-8000-00805F9B34FB"
    static let kManufacturerNameCharacteristic = "00002A29-0000-1000-8000-00805F9B34FB"
    static let kSoftwareRevisionCharacteristic = "00002A28-0000-1000-8000-00805F9B34FB"
    static let kFirmwareRevisionCharacteristic = "00002A26-0000-1000-8000-00805F9B34FB"

    // Data
    static let kDisServiceUUID = CBUUID(string: FirmwareUpdater.kDeviceInformationService)
    static let kDfuServiceUUID = CBUUID(string: FirmwareUpdater.kNordicDeviceFirmwareUpdateService)
    static let kManufacturerCharacteristicUUID = CBUUID(string: FirmwareUpdater.kManufacturerNameCharacteristic)
    static let kModelNumberCharacteristicUUID = CBUUID(string: FirmwareUpdater.kModelNumberCharacteristic)
    static let kSoftwareRevisionCharacteristicUUID = CBUUID(string: FirmwareUpdater.kSoftwareRevisionCharacteristic)
    static let kFirmwareRevisionCharacteristicUUID = CBUUID(string: FirmwareUpdater.kFirmwareRevisionCharacteristic)

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

    func releases(showBetaVersions: Bool) -> [String: BoardInfo]? {
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
                self?.servicesDiscovered(peripheral: peripheral, delegate: delegate, shouldRecommendBetaReleases: shouldRecommendBetaReleases, versionToIgnore: versionToIgnore)
            }
        } else {
            servicesDiscovered(peripheral: peripheral, delegate: delegate, shouldRecommendBetaReleases: shouldRecommendBetaReleases, versionToIgnore: versionToIgnore)
        }
    }

    private func servicesDiscovered(peripheral: BlePeripheral, delegate: FirmwareUpdaterDelegate, shouldRecommendBetaReleases: Bool, versionToIgnore: String?) {
        guard let _ = peripheral.discoveredService(uuid: FirmwareUpdater.kDfuServiceUUID), let disService = peripheral.discoveredService(uuid: FirmwareUpdater.kDisServiceUUID) else {
            DLog("Updates: Peripheral has no DFU or DIS service available")
            DispatchQueue.main.async {
                delegate.onFirmwareUpdateAvailable(isUpdateAvailable: false, latestRelease: nil, deviceDfuInfo: nil)
            }
            return
        }

        DLog("Discover DIS Characteristics")
        // Note: macOS seems to have problems discovering a specific set of characteristics, so nil is passed to discover all of them
        peripheral.discover(characteristicUuids: nil, service: disService) { [weak self] error in
            guard let strongSelf = self else { return }

            guard error == nil else {
                DLog("Error discovering DIS characteristics")
                return
            }

            DLog("Read DIS characteristics")
            var deviceDfuInfo = DeviceDfuInfo()
            let dispatchGroup = DispatchGroup()         // Wait till all the required characteristics are read to continue

            // Manufacturer
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kManufacturerCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { deviceDfuInfo.manufacturer = $0 }
            // Model Number
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kModelNumberCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { deviceDfuInfo.modelNumber = $0 }
            // Firmware Revision
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kFirmwareRevisionCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { deviceDfuInfo.firmwareRevision = $0 }
            // Software Revision
            strongSelf.readCharacteristic(uuid: FirmwareUpdater.kSoftwareRevisionCharacteristicUUID, peripheral: peripheral, service: disService, dispatchGroup: dispatchGroup) { deviceDfuInfo.softwareRevision = $0 }

            // All read
            dispatchGroup.notify(queue: .global(), execute: { [weak strongSelf] in
                DLog("Device Info Data received")
                strongSelf?.checkUpdatesForDeviceInfoService(deviceDfuInfo, shouldRecommendBetaReleases: shouldRecommendBetaReleases, versionToIgnore: versionToIgnore, delegate: delegate)
            })
        }
    }

    private func readCharacteristic(uuid: CBUUID, peripheral: BlePeripheral, service: CBService, dispatchGroup: DispatchGroup, completion: @escaping ((String?) -> Void)) {
        dispatchGroup.enter()
        if let characteristic = peripheral.discoveredCharacteristic(uuid: uuid, service: service) {
            peripheral.readCharacteristic(characteristic) { (value, error) in
                defer { dispatchGroup.leave() }
                guard error == nil, let data = value as? Data, let stringValue = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }

                completion(stringValue)
            }
        } else {
            DLog("Warning: updates check didn't find characteristic: \(uuid.uuidString)")
            dispatchGroup.leave()
        }
    }

    private func checkUpdatesForDeviceInfoService(_ deviceDfuInfo: DeviceDfuInfo, shouldRecommendBetaReleases: Bool, versionToIgnore: String?, delegate: FirmwareUpdaterDelegate) {
        var isFirmwareUpdateAvailable = false
        var latestRelease: FirmwareInfo?
        let allReleases = releases(showBetaVersions: shouldRecommendBetaReleases)

        if let allReleases = allReleases {
            if deviceDfuInfo.firmwareRevision != nil {
                if !deviceDfuInfo.hasDefaultBootloaderVersion {       // Nordic dfu library for iOS doesn't work with the default booloader version
                    if let manufacturer = deviceDfuInfo.manufacturer, FirmwareUpdater.kManufacturer.caseInsensitiveCompare(manufacturer) == .orderedSame {
                        if let modelNumber = deviceDfuInfo.modelNumber, let boardInfo = allReleases[modelNumber] {
                            let modelReleases = boardInfo.firmwareReleases
                            if !modelReleases.isEmpty {
                                // Get the latest release
                                let filteredModelReleases = modelReleases.filter {!$0.isBeta || shouldRecommendBetaReleases}
                                latestRelease = filteredModelReleases.first

                                // Check if the bootloader is compatible with this version
                                if let latestRelease = latestRelease, let minBootloaderVersion = latestRelease.minBootloaderVersion, let bootloaderVersion = deviceDfuInfo.bootloaderVersion, bootloaderVersion.compare(minBootloaderVersion, options: [.numeric]) != .orderedAscending {

                                    // Check if the user chose to ignore this version
                                    if versionToIgnore == nil || latestRelease.version.compare(versionToIgnore!, options: [.numeric]) != .orderedSame {

                                        let isNewerVersion = deviceDfuInfo.softwareRevision != nil && latestRelease.version.compare(deviceDfuInfo.softwareRevision!, options: [.numeric]) == .orderedDescending
                                        isFirmwareUpdateAvailable = isNewerVersion
                                        #if DEBUG
                                            if isNewerVersion {
                                                DLog("Updates: New version found. Ask the user to install: \(latestRelease.version)")
                                            } else {
                                                DLog("Updates: Device has already latest version: \(deviceDfuInfo.softwareRevision ?? "<unknown>")")
                                            }
                                        #endif
                                    } else {
                                        DLog("Updates: User ignored version: \(versionToIgnore ?? "<unknown>"). Skipping...")
                                    }
                                } else {
                                    DLog("Updates: Bootloader version \(deviceDfuInfo.bootloaderVersion ?? "<unknown>") below minimum needed: \(latestRelease?.minBootloaderVersion ?? "<unknown>")")
                                }
                            } else {
                                DLog("Updates: No firmware releases found for model: \(deviceDfuInfo.modelNumber ?? "<unknown>")")
                            }
                        } else {
                            DLog("Updates: No releases found for model: \(deviceDfuInfo.modelNumber ?? "<unknown>")")
                        }
                    } else {
                        DLog("Updates: No updates for unknown manufacturer: \(deviceDfuInfo.manufacturer ?? "<unknown>")")
                    }
                } else {
                    DLog("Updates: The legacy bootloader on this device is not compatible with this application")
                }
            } else {
                DLog("Updates: firmwareRevision not defined")
            }
        } else {
            DLog("Updates: releases array is empty")
        }

        delegate.onFirmwareUpdateAvailable(isUpdateAvailable: isFirmwareUpdateAvailable, latestRelease: latestRelease, deviceDfuInfo: deviceDfuInfo)
    }
}
