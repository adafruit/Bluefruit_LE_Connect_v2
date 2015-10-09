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
    var lastSeenTime : CFAbsoluteTime
    
    class UartData {
        var receivedBytes : Int64 = 0
        var sentBytes : Int64 = 0
    }
    var uartData = UartData()

    var name : String {
        get {
            if let name = peripheral.name {
                return name
            }
            else {
                return "<No Name>"
            }
        }
    }
    
    init(peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
    }
    

}