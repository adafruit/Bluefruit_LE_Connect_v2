//
//  Scanner.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 17/05/16.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import Foundation

class Scanner {
    
    private var discoveredPeripheralsIdentifiers = [String]()
    
    func start() {
        // Subscribe to Ble Notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(didDiscoverPeripheral(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        
        BleManager.sharedInstance.startScan()
    }
    
    @objc func didDiscoverPeripheral(notification : NSNotification) {
        
        if let uuid = notification.userInfo?["uuid"] as? String {
            
            if let peripheral = BleManager.sharedInstance.blePeripherals()[uuid] {
                
                if !discoveredPeripheralsIdentifiers.contains(uuid) {
                    discoveredPeripheralsIdentifiers.append(uuid)
                    
                    let name = peripheral.name != nil ? peripheral.name! : "{No Name}"
                    print("\(uuid): \(name)")
                }
            }
        }
    }
}