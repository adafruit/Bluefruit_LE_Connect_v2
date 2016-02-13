//
//  BlePeripheral.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BlePeripheral {
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
                return LocalizationManager.sharedInstance.localizedString("peripherallist_unnamed")
            }
        }
    }
    
    init(peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
    }
    
    func isUartAdvertised() -> Bool {
        let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
        
        var isUartAdvertised = false
        if let serviceUUIds = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            isUartAdvertised = serviceUUIds.contains(CBUUID(string: kUartServiceUUID))
        }
        return isUartAdvertised
    }
    

}