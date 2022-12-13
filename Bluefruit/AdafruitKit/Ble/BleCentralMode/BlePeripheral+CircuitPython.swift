//
//  BlePeripheral+CircuitPython.swift
//  Bluefruit
//
//  Created by Antonio García on 8/12/22.
//  Copyright © 2022 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

extension BlePeripheral {
    // Costants
    static let kCircuitPythonServiceUUID = CBUUID(string: "ADAF0001-4369-7263-7569-74507974686e")
    static let kCircuitPythonTxCharacteristicUUID =  CBUUID(string: "ADAF0002-4369-7263-7569-74507974686e")
    static let kCircuitPythonRxCharacteristicUUID =  CBUUID(string: "ADAF0003-4369-7263-7569-74507974686e")

    // MARK: - Utils    
    func hasCircuitPython() -> Bool {
        return peripheral.services?.first(where: {$0.uuid == BlePeripheral.kCircuitPythonServiceUUID}) != nil
    }
}

