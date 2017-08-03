//
//  GattServer.swift
//  Bluefruit
//
//  Created by Antonio García on 03/08/2017.
//  Copyright © 2017 Adafruit. All rights reserved.
//

import Foundation
import CoreBluetooth

class GattServer: NSObject {
    
    var autostartAdvertising = true
    var advertisementLocalName: String? = "Bluefruit"
    
    fileprivate var peripheralManager: CBPeripheralManager!
    fileprivate var isAdvertisingService = false
    
    /*
    public var state: CBManagerState {
        return peripheralManager.state
    }*/
    
    override public init() {
        super.init()
        
        // Peripheral Manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main, options: [CBPeripheralManagerOptionShowPowerAlertKey: false, /*CBPeripheralManagerOptionRestoreIdentifierKey: GattServer.kPeripheralManagerIdentifier*/])
    }

    deinit {
    }
    
    public func startAdvertising() {
        guard !isAdvertisingService, peripheralManager.state == .poweredOn else { return }
        
        DLog("Enabling Advertising")
        
        // Clean / Setup
        stopAdvertising()
        
/*
        // Add services / chars
        viaMobileService.characteristics = [tokenCharacteristic, ticketCharacteristic, resultCharacteristic, testCharacteristic]
        peripheralManager.add(viaMobileService)
  */
        
        // Start advertising
        let manufacturerBytes: [UInt8] = [0x00, 0x03, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let manufacturerData = Data(bytes: manufacturerBytes)
        var advertisementData: [String : Any] = [CBAdvertisementDataManufacturerDataKey: manufacturerData]
        if let advertisementLocalName = advertisementLocalName {
            advertisementData[CBAdvertisementDataLocalNameKey] = advertisementLocalName
        }
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertisingService = true
    }
    
    public func stopAdvertising() {
        guard isAdvertisingService else { return }
        
        DLog("Stop Advertising")
        
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        
        isAdvertisingService = false
    }

    public func isAdvertising() -> Bool {
        return isAdvertisingService
    }
}

// MARK: - CBPeripheralManagerDelegate
extension GattServer: CBPeripheralManagerDelegate {
    
    // MARK: Monitoring Changes to the Peripheral Manager’s State
    public func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        DLog("peripheralManagerDidUpdateState: \(manager.state.rawValue)")
        
        if manager.state == .poweredOn {
            if autostartAdvertising && !isAdvertisingService {
                startAdvertising()
            }
        }
        
//        NotificationCenter.default.post(name: .didUpdatePeripheralState, object: nil)
    }
    
    /*
     func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
     DLog("willRestoreState: \(dict)")
     }*/
    
    // MARK: Adding Services
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else { DLog("didAddService error: \(error!)"); return }
        DLog("AddService: \(service.uuid.uuidString)")
    }
    
    // MARK: Advertising Peripheral Data
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        guard error == nil else { DLog("peripheralManagerDidStartAdvertising error: \(error!)"); return }
        DLog("didStartAdvertising")
    }
    
    // MARK: Monitoring Subscriptions to Characteristic Values
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        DLog("didSubscribeTo: \(characteristic.uuid.uuidString)")
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        DLog("didUnsubscribeFrom: \(characteristic.uuid.uuidString)")
    }
    
    // MARK: Receiving Read and Write Requests
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        DLog("didReceiveRead for characteristic: \(request.characteristic.uuid.uuidString)")
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        DLog("peripheralManagerIsReady")
    }
}
