//
//  PeripheralService.swift
//  Bluefruit
//
//  Created by Antonio García on 04/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth


protocol PeripheralServiceDelegate: class {
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?)
}

class PeripheralService {
    
    // Data
    public var name = LocalizationManager.sharedInstance.localizedString("peripheral_unknown_title")
    public var isEnabled = true
    public var service: CBMutableService!
    internal var characteristics: [CBMutableCharacteristic]!
    public weak var delegate: PeripheralServiceDelegate?
    
    internal var subscribedCharacteristics = [CBUUID : Set<CBCentral>]()
    
    // MARK: -
    public func characteristic(uuid: CBUUID) -> CBCharacteristic? {
        return service.characteristics?.first(where: {$0.uuid == uuid})
    }
    
    public func setCharacteristic(uuid characteristicUuid: CBUUID, value: Data) {
        let mutableCharacteristic = characteristics?.first(where: {$0.uuid == characteristicUuid})
        mutableCharacteristic?.value = value
    }
    
    public func subscribe(characteristicUuid: CBUUID, central: CBCentral) {
        if var existingSubscribedCharacteristic = subscribedCharacteristics[characteristicUuid] {
            existingSubscribedCharacteristic.insert(central)
        }
        else {
            subscribedCharacteristics[characteristicUuid] = [central]
        }
    }
    
    public func unsubscribe(characteristicUuid: CBUUID, central: CBCentral) {
        if var existingSubscribedCharacteristic = subscribedCharacteristics[characteristicUuid] {
            existingSubscribedCharacteristic.remove(central)
        }
    }
    
    public func centralsSubscribedToCharacteristic(uuid characteristicUuid: CBUUID) -> [CBCentral]? {
        var result: [CBCentral]?
        
        if let subscribedCentrals = subscribedCharacteristics[characteristicUuid] {
            result = Array(subscribedCentrals)
        }
        
        return result
    }
}
