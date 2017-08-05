//
//  UartPeripheralService.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import UIKit
import CoreBluetooth

class UartPeripheralService: PeripheralService {
    // Specs: https://learn.adafruit.com/introducing-adafruit-ble-bluetooth-low-energy-friend/uart-service
    
    // Service
    private static let kUartServiceUUID =           CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    
    // Characteristics
    private static let kUartTxCharacteristicUUID =  CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    private static let kUartRxCharacteristicUUID =  CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    fileprivate let txCharacteristic = CBMutableCharacteristic(type: UartPeripheralService.kUartTxCharacteristicUUID, properties: [.write, .writeWithoutResponse], value: nil, permissions: [.writeable])
    fileprivate let rxCharacteristic = CBMutableCharacteristic(type: UartPeripheralService.kUartTxCharacteristicUUID, properties: [.read, .notify], value: nil, permissions: [.readable])
    
    var tx: Data? {
        get {
            return txCharacteristic.value
        }
        set {
            txCharacteristic.value = newValue
        }
    }
    
    var rx: Data? {
        get {
            return rxCharacteristic.value
        }
        set {
            rxCharacteristic.value = newValue
        }
    }
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        
        name = "UART"
        
        service = CBMutableService(type: UartPeripheralService.kUartServiceUUID, primary: true)
        characteristics = [txCharacteristic, rxCharacteristic]
        service.characteristics = characteristics
    }
}
