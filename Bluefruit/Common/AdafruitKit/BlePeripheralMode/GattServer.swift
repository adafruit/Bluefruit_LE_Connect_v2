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
    
    var advertisementLocalName: String? = "Bluefruit"
    
    fileprivate var isStartAdvertisingAsSoonIsPoweredOnEnabled = false
    fileprivate var peripheralManager: CBPeripheralManager!
    fileprivate var isAdvertisingService = false
    
    fileprivate var peripheralServices = [PeripheralService]()
    
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
    
    public func addService(_ service: PeripheralService) {
        peripheralServices.append(service)
    }
    
    public func removeService(_ service: PeripheralService) {
        if let index = peripheralServices.index(where: {$0.service.uuid.isEqual($0.service.uuid)}) {
            peripheralServices.remove(at: index)
        }
    }
    
    public func removeAllServices() {
        peripheralServices.removeAll()
    }
    
    public func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            isStartAdvertisingAsSoonIsPoweredOnEnabled = true
            return
        }
        
        DLog("Enabling Advertising")
        
        // Clean / Setup
        stopAdvertising()
        
        // Add services / chars
        for peripheralService in peripheralServices {
            peripheralManager.add(peripheralService.service)
        }
        
        // Start advertising
        var advertisementData: [String : Any] = [:]
        if let advertisementLocalName = advertisementLocalName {
            advertisementData[CBAdvertisementDataLocalNameKey] = advertisementLocalName
        }
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertisingService = true
    }
    
    public func stopAdvertising() {
        isStartAdvertisingAsSoonIsPoweredOnEnabled = false
        guard isAdvertisingService else { return }
        
        DLog("Stop Advertising")
        
        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()
        
        isAdvertisingService = false
    }

    public func isAdvertising() -> Bool {
        return isAdvertisingService
    }
    
    
    // MARK: - Request Processing
    fileprivate func processReadRequest(_ request: CBATTRequest, value: Data?) {
        
        guard let value = value else {
            request.value = nil
            peripheralManager.respond(to: request, withResult: .success)
            DLog("read response: nil")
            return
        }
        
        guard request.offset < value.count else {
            DLog("Read request received with invalid offset")
            peripheralManager.respond(to: request, withResult: .invalidOffset)
            return
        }
        
        if request.offset == 0 {
            request.value = value
        }
        else {
            request.value = value.subdata(in: Range(request.offset..<value.count))
        }
        
        peripheralManager.respond(to: request, withResult: .success)
        
        DLog("read response: \(String(data: value, encoding: .utf8) ?? "<not utf8>")")
    }

}

// MARK: - CBPeripheralManagerDelegate
extension GattServer: CBPeripheralManagerDelegate {
    
    // MARK: Monitoring Changes to the Peripheral Manager’s State
    public func peripheralManagerDidUpdateState(_ manager: CBPeripheralManager) {
        DLog("peripheralManagerDidUpdateState: \(manager.state.rawValue)")
        
        if manager.state == .poweredOn {
            if isStartAdvertisingAsSoonIsPoweredOnEnabled && !isAdvertisingService {
                startAdvertising()
            }
        }
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
        
        let serviceUuid = request.characteristic.service.uuid
        for peripheralService in peripheralServices {
            if serviceUuid == peripheralService.service.uuid {
                let characteristicUuid = request.characteristic.uuid
                if let characteristic = peripheralService.characteristic(uuid: characteristicUuid) {
                    processReadRequest(request, value: characteristic.value)
                }
            }
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        DLog("peripheralManagerIsReady")
    }
}
