//
//  BleManager.swift
//  bluefruitconnect
//
//  Created by Antonio García on 23/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class BleManager : NSObject, CBCentralManagerDelegate {
    
    // Configuration
    static let kStopScanningWhenConnectingToPeripheral = false
    static let kUseBakgroundQueue = true
    static let kAlwaysAllowDuplicateKeys = true
    
    static let kIsUndiscoverPeripheralsEnabled = false                   // If true, the BleManager will check periodically if devices are no longer in range (warning: this could cause problems if for some peripherals that dont update its status for a long time)
    static let kUndiscoverCheckPeriod = 1.0                             // in seconds
    static let kUndiscoverPeripheralConsideredOutOfRangeTime = 50.0      // in seconds
    
    // Notifications
    enum BleNotifications : String {
        case DidUpdateBleState = "didUpdateBleState"
        case DidStartScanning = "didStartScanning"
        case DidStopScanning = "didStopScanning"
        case DidDiscoverPeripheral = "didDiscoverPeripheral"
        case DidUnDiscoverPeripheral = "didUnDiscoverPeripheral"
        case WillConnectToPeripheral = "willConnectToPeripheral"
        case DidConnectToPeripheral = "didConnectToPeripheral"
        case WillDisconnectFromPeripheral = "willDisconnectFromPeripheral"
        case DidDisconnectFromPeripheral = "didDisconnectFromPeripheral"
    }
    
    // Main
    static let sharedInstance = BleManager()
    var centralManager: CBCentralManager?
    
    // Scanning
    var isScanning = false
    var wasScanningBeforeBluetoothOff = false;
    private var blePeripheralsFound = [String : BlePeripheral]()
    var blePeripheralConnecting: BlePeripheral?
    var blePeripheralConnected: BlePeripheral?             // last peripheral connected (note: only one peripheral can can be connected at the same time
    var undiscoverTimer: NSTimer?
    
    //
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: BleManager.kUseBakgroundQueue ? dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0) : nil)
    }
    
    func restoreCentralManager() {
        // Restore central manager delegate if was changed
        centralManager?.delegate = self
    }
    
    func startScan() {
        guard let centralManager = centralManager where centralManager.state != .PoweredOff && centralManager.state != .Unauthorized && centralManager.state != .Unsupported else {
            DLog("startScan failed because central manager is not ready")
            return
        }
                
        //DLog("startScan");
        isScanning = true
        wasScanningBeforeBluetoothOff = true
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStartScanning.rawValue, object: nil)
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
            undiscoverTimer = NSTimer.scheduledTimerWithTimeInterval(BleManager.kUndiscoverCheckPeriod, target: self, selector:#selector(BleManager.checkUndiscoveredPeripherals), userInfo: nil, repeats: true)
        }
        
        let allowDuplicateKeys = BleManager.kAlwaysAllowDuplicateKeys || BleManager.kIsUndiscoverPeripheralsEnabled
        let scanOptions = allowDuplicateKeys ? [CBCentralManagerScanOptionAllowDuplicatesKey : true] as [String: AnyObject]? : nil
        centralManager.scanForPeripheralsWithServices(nil, options: scanOptions)
    }
    
    func stopScan() {
        //DLog("stopScan");
        
        centralManager?.stopScan()
        isScanning = false
        wasScanningBeforeBluetoothOff = false
        if (BleManager.kIsUndiscoverPeripheralsEnabled) {
            undiscoverTimer?.invalidate()
            undiscoverTimer = nil
        }
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidStopScanning.rawValue, object: nil)
    }
    
    func refreshPeripherals() {
        stopScan()
        
        synchronize(blePeripheralsFound) {
            self.blePeripheralsFound.removeAll()
            
            // Don't remove connnected or connecting peripherals
            if let connected = self.blePeripheralConnected {
                self.blePeripheralsFound[connected.peripheral.identifier.UUIDString] = connected;
            }
            if let connecting = self.blePeripheralConnecting {
                self.blePeripheralsFound[connecting.peripheral.identifier.UUIDString] = connecting;
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil);
        startScan()
    }
    
    
    func connect(blePeripheral: BlePeripheral) {
        
        // Stop scanning when connecting to a peripheral (to improve discovery time)
        if (BleManager.kStopScanningWhenConnectingToPeripheral) {
            stopScan()
        }
        
        // Connect
        blePeripheralConnecting = blePeripheral
       // DLog("connecting to: \(blePeripheral.name)")
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillConnectToPeripheral.rawValue, object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.UUIDString])
        
        centralManager?.connectPeripheral(blePeripheral.peripheral, options: nil)
    }
    
    
    func disconnect(blePeripheral: BlePeripheral) {
        
       // DLog("disconnecting from: \(blePeripheral.name)")
        blePeripheralConnecting = nil
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil, userInfo: ["uuid" : blePeripheral.peripheral.identifier.UUIDString])
        centralManager?.cancelPeripheralConnection(blePeripheral.peripheral)
    }
    
    func discover(blePeripheral : BlePeripheral, serviceUUIDs: [CBUUID]?) {
        DLog("discover services")
        blePeripheral.peripheral.discoverServices(serviceUUIDs)
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager) {
        DLog("centralManagerDidUpdateState \(central.state.rawValue)")
        
        if (central.state == .PoweredOn) {
            if (wasScanningBeforeBluetoothOff) {
                startScan();        // Continue scanning now that bluetooth is back
            }
        }
        else {
            if let blePeripheralConnected = blePeripheralConnected {
                DLog("Bluetooth is not powered on. Disconnect connected peripheral")
                blePeripheralConnecting = nil
                disconnect(blePeripheralConnected)
            }
            
            isScanning = false
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUpdateBleState.rawValue, object: nil, userInfo: ["state" : central.state.rawValue])
    }
    
    func checkUndiscoveredPeripherals() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        synchronize(blePeripheralsFound) {
            for (identifier, blePeripheral) in self.blePeripheralsFound {
                if identifier != self.blePeripheralConnected?.peripheral.identifier.UUIDString { // Don't hide the connected peripheral
                    let elapsedTime = currentTime - blePeripheral.lastSeenTime
                    if elapsedTime > BleManager.kUndiscoverPeripheralConsideredOutOfRangeTime {
                        DLog("undiscovered peripheral: \(blePeripheral.name)")
                        self.blePeripheralsFound.removeValueForKey(identifier)
                        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil, userInfo: ["uuid" : identifier]);
                    }
                }
                //            let elapsedFormatted = String(format:"%.2f", elapsedTime)
                //            DLog("peripheral \(blePeripheral.name): elapsed \( elapsedFormatted )")
            }
        }
        
        // DLog("--")
    }
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral,  advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        let identifierString = peripheral.identifier.UUIDString
        //DLog("didDiscoverPeripheral \(peripheral.name)")
        synchronize(blePeripheralsFound) {
            if let existingPeripheral = self.blePeripheralsFound[identifierString] {
                // Existing peripheral. Update advertisement data because each time is discovered the advertisement data could miss some of the keys (sometimes a sevice is there, and other times has dissapeared)
                
                existingPeripheral.rssi = RSSI.integerValue
                existingPeripheral.lastSeenTime = CFAbsoluteTimeGetCurrent()
                for (key, value) in advertisementData {
                    existingPeripheral.advertisementData.updateValue(value, forKey: key);
                }
                self.blePeripheralsFound[identifierString] = existingPeripheral
                
            }
            else {      // New peripheral found
                //DLog("New peripheral found: \(identifierString) - \(peripheral.name != nil ? peripheral.name!:"")")
                let blePeripheral = BlePeripheral(peripheral: peripheral, advertisementData: advertisementData, RSSI: RSSI.integerValue)
                self.blePeripheralsFound[identifierString] = blePeripheral
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDiscoverPeripheral.rawValue, object:nil, userInfo: ["uuid" : identifierString]);
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        //DLog("didConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        blePeripheralConnecting = nil
        let identifier = peripheral.identifier.UUIDString;
        synchronize(blePeripheralsFound) {
            self.blePeripheralConnected = self.blePeripheralsFound[identifier]
        }
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidConnectToPeripheral.rawValue, object: nil, userInfo: ["uuid" : identifier])
    }
    
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("didDisconnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        peripheral.delegate = nil
        if peripheral.identifier == blePeripheralConnected?.peripheral.identifier {
            self.blePeripheralConnected = nil
        }
        self.blePeripheralConnecting = nil
        
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil,  userInfo: ["uuid" : peripheral.identifier.UUIDString])
    }
    
    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        DLog("didFailToConnectPeripheral: \(peripheral.name != nil ? peripheral.name! : "")")
        
        blePeripheralConnecting = nil
        NSNotificationCenter.defaultCenter().postNotificationName(BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil,  userInfo: ["uuid" : peripheral.identifier.UUIDString])
    }
    
    // MARK: - Utils
    func blePeripherals() -> [String : BlePeripheral] {         // To avoid race conditions when modifying the array
        var result: [String : BlePeripheral]?
        synchronize(blePeripheralsFound) { [unowned self] in
            result = self.blePeripheralsFound
        }
        
        return result!
    }
    
    func blePeripheralsCount() -> Int {                          // To avoid race conditions when modifying the array
        var result = 0
        
        synchronize(blePeripheralsFound) { [unowned self] in
            result = self.blePeripheralsFound.count
        }
        
        return result
    }
    
    func blePeripheralFoundAlphabeticKeys() -> [String] {
        // Sort blePeripheralsFound keys alphabetically and return them as an array
        
        var sortedKeys : [String] = []
        synchronize(blePeripheralsFound) {
            sortedKeys = Array(self.blePeripheralsFound.keys).sort({[weak self] in self?.blePeripheralsFound[$0]?.name < self?.blePeripheralsFound[$1]?.name})
        }
        return sortedKeys
    }
}