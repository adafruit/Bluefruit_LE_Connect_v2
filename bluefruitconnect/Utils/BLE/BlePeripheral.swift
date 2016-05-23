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
    
    var name : String? {
        get {
            return peripheral.name
        }
    }
    
    init(peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = RSSI
        self.lastSeenTime = CFAbsoluteTimeGetCurrent()
    }
    
    // MARK: - Uart
    private static let kUartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    class UartData {
        var receivedBytes : Int64 = 0
        var sentBytes : Int64 = 0
    }
    var uartData = UartData()

    func isUartAdvertised() -> Bool {
        
        var isUartAdvertised = false
        if let serviceUUIds = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            isUartAdvertised = serviceUUIds.contains(CBUUID(string: BlePeripheral.kUartServiceUUID))
        }
        return isUartAdvertised
    }
    
    func hasUart() -> Bool {
        var hasUart = false
        if let services = peripheral.services {
            hasUart = services.contains({ (service : CBService) -> Bool in
                service.UUID.isEqual(CBUUID(string: BlePeripheral.kUartServiceUUID))
            })
        }
        return hasUart
    }
}