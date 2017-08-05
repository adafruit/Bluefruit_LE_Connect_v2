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
    
    // Costants
    static let kUartServiceUUID =           CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartTxCharacteristicUUID =  CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    static let kUartRxCharacteristicUUID =  CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
}
