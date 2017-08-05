//
//  DeviceInformationPeripheralService.swift
//  Bluefruit
//
//  Created by Antonio García on 04/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class DeviceInformationPeripheralService: PeripheralService {
    // Specs: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.service.device_information.xml
    
    // Service
    private static let kDisServiceUUID = CBUUID(string: "180A")
    
    // Characteristics
    private static let kManufacturerNameCharacteristicUUID = CBUUID(string: "2A29")
    private static let kModelNumberCharacteristicUUID = CBUUID(string: "2A24")
    private static let kSerialNumberCharacteristicUUID = CBUUID(string: "2A25")
    private static let kHardwareNumberCharacteristicUUID = CBUUID(string: "2A76")
    private static let kFirmwareRevisionCharacteristicUUID = CBUUID(string: "2A26")
    private static let kSoftwareRevisionCharacteristicUUID = CBUUID(string: "2A28")
    
    fileprivate let manufacturerNameCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kManufacturerNameCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    fileprivate let modelNumberCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kModelNumberCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    fileprivate let serialNumberCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kSerialNumberCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    fileprivate let hardwareNumberCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kHardwareNumberCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    fileprivate let firmwareRevisionCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kFirmwareRevisionCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    fileprivate let softwareRevisionCharacteristic = CBMutableCharacteristic(type: DeviceInformationPeripheralService.kSoftwareRevisionCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
    
    
    var manufacturer: String? {
        get {
            guard let manufacturerData = manufacturerNameCharacteristic.value else { return nil }
            return String(data: manufacturerData, encoding: .utf8)
        }
        set {
            manufacturerNameCharacteristic.value = manufacturer?.data(using: .utf8)
        }
    }
    
    // MARK: - View Lifecycle
    override init() {
        super.init()
        
        name = "Device Information Service"
        
        service = CBMutableService(type: DeviceInformationPeripheralService.kDisServiceUUID, primary: true)
        characteristics = [manufacturerNameCharacteristic, modelNumberCharacteristic, serialNumberCharacteristic, hardwareNumberCharacteristic, firmwareRevisionCharacteristic, softwareRevisionCharacteristic]
        service.characteristics = characteristics
        
        loadValues()
    }
    
    // MARK: -
    func saveValues() {
        guard let characteristics = service.characteristics else { return }
        UserDefaults.standard.set(isEnabled, forKey: service.uuid.uuidString+"_isEnabled")
        for characteristic in characteristics {
            let value = characteristic.value
            UserDefaults.standard.set(value, forKey: characteristic.uuid.uuidString)
        }
    }
    
    func loadValues() {
        isEnabled = (UserDefaults.standard.value(forKey: service.uuid.uuidString+"_isEnabled") as? Bool) ?? true
        for characteristic in characteristics {
            if let value = UserDefaults.standard.value(forKey: characteristic.uuid.uuidString) as? Data? {
                characteristic.value = value
            }
        }
    }
    
}
