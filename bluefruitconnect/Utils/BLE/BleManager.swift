//
//  BleManager.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BleManager :  NSObject, CBCentralManagerDelegate {
    
    enum BleNotifications : String {
        case DidUpdateState = "didUpdateState"
        case DidStartScanning = "didStartScanning"
        case DidStopScanning = "didStopScanning"
        case DidDiscoverPeripheral = "didDiscoverPeripheral"
        case WillConnectToPeripheral = "willConnectToPeripheral"
        case DidConnectToPeripheral = "didConnectToPeripheral"
        case WillDisconnectFromPeripheral = "willDisconnectFromPeripheral"
        case DidDisconnectFromPeripheral = "didDisconnectFromPeripheral"
    }
    
    static let sharedInstance = BleManager()
    
    // Main
    var centralManager : CBCentralManager?
    
    // Scanning
    var blePeripheralsFound = [String : BlePeripheral]()
    var blePeripheralConnected : BlePeripheral?             // last peripheral connected (take into account that multiple peripherals can can be connected at the same time

    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func restoreCentralManager() {
        // Restore central manager delegate if was changed
        centralManager?.delegate = self
    }
    
    func startScan() {
        DLog("startScan");
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStartScanning.rawValue, object: nil)

        centralManager?.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    func stopScan() {
        DLog("stopScan");
        
        centralManager?.stopScan()
    
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStopScanning.rawValue, object: nil)
    }
    
    func connect(blePeripheral : BlePeripheral) {
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillConnectToPeripheral.rawValue, object: nil)

        centralManager?.connectPeripheral(blePeripheral.peripheral, options: nil)
    }
    
    func disconnect(blePeripheral : BlePeripheral) {

        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillDisconnectFromPeripheral.rawValue, object: blePeripheral.peripheral.identifier.UUIDString)
        centralManager?.cancelPeripheralConnection(blePeripheral.peripheral)
        
       
    }
    
    func discover(blePeripheral : BlePeripheral, serviceUUIDs: [CBUUID]?) {
        blePeripheral.peripheral.discoverServices(serviceUUIDs)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        DLog("centralManagerDidUpdateState \(central.state.rawValue)")
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUpdateState.rawValue, object: central.state.rawValue)
        
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let identifierString = peripheral.identifier.UUIDString
        
        if var existingPeripheral = blePeripheralsFound[identifierString] {
            // Existing peripheral. Update advertisement data because each time is discovered the advertisement data could miss some of the keys (sometimes a sevice is there, and other times has dissapeared)
            for (key, value) in advertisementData {
                existingPeripheral.advertisementData.updateValue(value, forKey: key);
            }
           
        }
        else {      // New peripheral found
            let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI.integerValue)
            blePeripheralsFound[identifierString] = blePeripheral
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDiscoverPeripheral.rawValue, object: identifierString);
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
         DLog("centralManager didConnectPeripheral \(peripheral.name)")
        
        let identifier = peripheral.identifier.UUIDString;
        blePeripheralConnected = blePeripheralsFound[identifier]
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidConnectToPeripheral.rawValue, object: identifier)
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("centralManager didDisconnectPeripheral \(peripheral.name)")

        peripheral.delegate = nil
        if peripheral.identifier == blePeripheralConnected?.peripheral.identifier {
            self.blePeripheralConnected = nil
        }

        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: peripheral.identifier.UUIDString)
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("centralManager didFailToConnectPeripheral \(peripheral.name)")
     
    }
    
    
   
}