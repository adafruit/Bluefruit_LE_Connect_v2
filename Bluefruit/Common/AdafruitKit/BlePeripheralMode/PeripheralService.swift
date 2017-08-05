//
//  PeripheralService.swift
//  Bluefruit
//
//  Created by Antonio García on 04/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class PeripheralService {
    
    public var name: String = "Undefined Peripheral"
    public var isEnabled = true
    public var service: CBMutableService!
    internal var characteristics: [CBMutableCharacteristic]!
    
    public func characteristic(uuid: CBUUID) -> CBCharacteristic? {
        return service.characteristics?.first(where: {$0.uuid == uuid})
    }
}
