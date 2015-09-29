//
//  BlePeripheral.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

struct BlePeripheral {
    var peripheral : CBPeripheral!
    var advertisementData : [String : AnyObject]
    var rssi : Int
    
    init(peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
    }
}