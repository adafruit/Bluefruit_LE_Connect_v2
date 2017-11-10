//
//  UartPeripheralService.swift
//  Bluefruit
//
//  Created by Antonio García on 05/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import CoreBluetooth

class UartPeripheralService: PeripheralService {
    // Specs: https://learn.adafruit.com/introducing-adafruit-ble-bluetooth-low-energy-friend/uart-service
    
    // Service
    static let kUartServiceUUID =                   CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    
    // Characteristics
    private static let kUartTxCharacteristicUUID =  CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    private static let kUartRxCharacteristicUUID =  CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    private let txCharacteristic = CBMutableCharacteristic(type: UartPeripheralService.kUartTxCharacteristicUUID, properties: [.write, .writeWithoutResponse], value: nil, permissions: [.writeable])
    private let rxCharacteristic = CBMutableCharacteristic(type: UartPeripheralService.kUartRxCharacteristicUUID, properties: [.read, .notify], value: nil, permissions: [.readable])

    private var uartRxHandler: ((Data?) -> Void)?
    
    // MARK: - Lifecycle
    override init() {
        super.init()
        
        name = LocalizationManager.sharedInstance.localizedString("peripheral_uart_title")
        
        service = CBMutableService(type: UartPeripheralService.kUartServiceUUID, primary: true)
        characteristics = [txCharacteristic, rxCharacteristic]
        service.characteristics = characteristics
    }

    // MARK: - Characteristics Read / Write / Subcription
    var tx: Data? {
        get {
            return txCharacteristic.value
        }
        set {
            txCharacteristic.value = newValue
            
            uartRxHandler?(newValue)
        }
    }
    
    var rx: Data? {
        get {
            return rxCharacteristic.value
        }
        set {
            rxCharacteristic.value = newValue
            
            if let data = newValue {
                let centralsSubscribed = centralsSubscribedToCharacteristic(uuid: UartPeripheralService.kUartRxCharacteristicUUID)
                delegate?.updateValue(data, for: rxCharacteristic, onSubscribedCentrals: centralsSubscribed)
            }
        }
    }
    
    func uartEnable(uartRxHandler: ((Data?) -> Void)?) {
        self.uartRxHandler = uartRxHandler
    }
    
    override public func setCharacteristic(uuid characteristicUuid: CBUUID, value: Data) {
        // Override behaviour for tx
        if characteristicUuid == UartPeripheralService.kUartTxCharacteristicUUID {
            tx = value
        }
        else if characteristicUuid == UartPeripheralService.kUartRxCharacteristicUUID {
            rx = value
        }
        else {
            super.setCharacteristic(uuid: characteristicUuid, value: value)
        }
    }
}
