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
            return characteristicText(characteristic: manufacturerNameCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: manufacturerNameCharacteristic)
        }
    }

    var modelNumber: String? {
        get {
            return characteristicText(characteristic: modelNumberCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: modelNumberCharacteristic)
        }
    }
    
    
    var serialNumber: String? {
        get {
            return characteristicText(characteristic: serialNumberCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: serialNumberCharacteristic)
        }
    }
    
    var hardwareNumber: String? {
        get {
            return characteristicText(characteristic: hardwareNumberCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: hardwareNumberCharacteristic)
        }
    }

    var firmwareRevision: String? {
        get {
            return characteristicText(characteristic: firmwareRevisionCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: firmwareRevisionCharacteristic)
        }
    }

    
    var softwareRevision: String? {
        get {
            return characteristicText(characteristic: softwareRevisionCharacteristic)
        }
        set {
            setCharacteristicText(newValue, characteristic: softwareRevisionCharacteristic)
        }
    }

    
    // MARK: - Lifecycle
    override init() {
        super.init()
        
        name = LocalizationManager.sharedInstance.localizedString("peripheral_dis_title")
        
        service = CBMutableService(type: DeviceInformationPeripheralService.kDisServiceUUID, primary: true)
        characteristics = [manufacturerNameCharacteristic, modelNumberCharacteristic, serialNumberCharacteristic, hardwareNumberCharacteristic, firmwareRevisionCharacteristic, softwareRevisionCharacteristic]
        service.characteristics = characteristics
        
        loadValues()
    }
    
    
    // MARK: -
    private func characteristicText(characteristic: CBCharacteristic) -> String? {
        guard let data = characteristic.value else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func setCharacteristicText(_ text: String?, characteristic: CBMutableCharacteristic) {
        characteristic.value = text?.data(using: .utf8)
    }
    
    func saveValues() {
        guard let characteristics = service.characteristics else { return }
        UserDefaults.standard.set(isEnabled, forKey: service.uuid.uuidString+"_isEnabled")
        for characteristic in characteristics {
            let value = characteristic.value
            UserDefaults.standard.set(value, forKey: characteristic.uuid.uuidString)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func loadValues() {
        isEnabled = (UserDefaults.standard.value(forKey: service.uuid.uuidString+"_isEnabled") as? Bool) ?? true
        for characteristic in characteristics {
            if let value = UserDefaults.standard.value(forKey: characteristic.uuid.uuidString) as? Data? {
                characteristic.value = value
            }
        }
    }
    
}
