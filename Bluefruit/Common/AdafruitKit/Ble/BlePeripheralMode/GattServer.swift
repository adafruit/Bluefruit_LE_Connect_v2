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
    
    var advertisementLocalName: String?  {
        get {
            return UserDefaults.standard.value(forKey: "advertisementLocalName") as? String
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: "advertisementLocalName")
            UserDefaults.standard.synchronize()
            startAdvertising()
        }
    }
    
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
        service.delegate = self
        peripheralServices.append(service)
    }
    
    public func removeService(_ service: PeripheralService) {
        if let index = peripheralServices.index(where: {$0.service.uuid.isEqual($0.service.uuid)}) {
            peripheralServices.remove(at: index)
            service.delegate = nil
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
            if peripheralService.isEnabled {
                peripheralManager.add(peripheralService.service)
            }
        }
        
        // Start advertising
        var advertisementData: [String : Any] = [:]
        if let advertisementLocalName = advertisementLocalName {
            advertisementData[CBAdvertisementDataLocalNameKey] = advertisementLocalName
        }
        
        let isUartServiceEnabled = peripheralServices.contains(where: { $0.service.uuid == UartPeripheralService.kUartServiceUUID && $0.isEnabled })
        if isUartServiceEnabled {
            // If UART is enabled, add the UUID to the advertisement packet
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = [UartPeripheralService.kUartServiceUUID]
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
    
    fileprivate func processWriteRequest(_ request: CBATTRequest, peripheralService: PeripheralService) {
        guard let newValue = request.value, let characteristic = peripheralService.characteristic(uuid: request.characteristic.uuid) else { return }
        
        var value = characteristic.value
        let size = request.offset + newValue.count
        if value == nil {
            value = newValue
        }
        else {
            if value!.count < size {        // If smaller than the size needed, expand the capacity
                value!.append(contentsOf: [UInt8](repeatElement(0x00, count: size - value!.count)))
            }
            value!.replaceSubrange(request.offset..<request.offset+newValue.count, with: newValue)
        }
        
        peripheralService.setCharacteristic(uuid: request.characteristic.uuid, value: value!)
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
        
        let serviceUuid = characteristic.service.uuid
        for peripheralService in peripheralServices {
            if serviceUuid == peripheralService.service.uuid {
                peripheralService.subscribe(characteristicUuid: characteristic.uuid, central: central)
            }
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        DLog("didUnsubscribeFrom: \(characteristic.uuid.uuidString)")
   
        let serviceUuid = characteristic.service.uuid
        for peripheralService in peripheralServices {
            if serviceUuid == peripheralService.service.uuid {
                peripheralService.unsubscribe(characteristicUuid: characteristic.uuid, central: central)
            }
        }
    }
    
    // MARK: Receiving Read and Write Requests
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        DLog("didReceiveRead for characteristic: \(request.characteristic.uuid.uuidString)")
        
        var isCharacteristicValid = false
        let serviceUuid = request.characteristic.service.uuid
        if let peripheralService = peripheralServices.first(where: {$0.service.uuid == serviceUuid}) {
            let characteristicUuid = request.characteristic.uuid
            if let characteristic = peripheralService.characteristic(uuid: characteristicUuid) {
                processReadRequest(request, value: characteristic.value)
                isCharacteristicValid = true
            }
        }
        
        /*
        for peripheralService in peripheralServices {
            if serviceUuid == peripheralService.service.uuid {
                let characteristicUuid = request.characteristic.uuid
                if let characteristic = peripheralService.characteristic(uuid: characteristicUuid) {
                    processReadRequest(request, value: characteristic.value)
                    characteristicFound = true
                }
            }
        }*/
        
        if !isCharacteristicValid {
            peripheralManager.respond(to: request, withResult: .readNotPermitted)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    
        // Check for pre-conditions (all requests MUST be valid)
        for request in requests {
            let serviceUuid = request.characteristic.service.uuid
            
            var isCharacteristicValid = false
            if let peripheralService = peripheralServices.first(where: {$0.service.uuid == serviceUuid}) {
                let characteristicUuid = request.characteristic.uuid
                if peripheralService.characteristic(uuid: characteristicUuid) != nil {
                    isCharacteristicValid = true
                }
            }
            /*
            for peripheralService in peripheralServices {
                if serviceUuid == peripheralService.service.uuid {
                    let characteristicUuid = request.characteristic.uuid
                    
                    if peripheralService.characteristic(uuid: characteristicUuid) != nil {
                        isCharacteristicValid = true
                    }
                }
            }*/
            
            guard isCharacteristicValid else {
                DLog("didReceiveWrite error. Aborting \(requests.count) write requests")
                peripheralManager.respond(to: request, withResult: .writeNotPermitted)
                return
            }
        }
        
        // Write
        for request in requests {
            DLog("didReceiveWrite for characteristic: \(request.characteristic.uuid.uuidString)")
            let serviceUuid = request.characteristic.service.uuid
            if let peripheralService = peripheralServices.first(where: {$0.service.uuid == serviceUuid}) {
                processWriteRequest(request, peripheralService: peripheralService)
            }
                /*
            for peripheralService in peripheralServices {
                if serviceUuid == peripheralService.service.uuid {
                    processWriteRequest(request, peripheralService: peripheralService)
                }
            }*/
        }
    
        peripheralManager.respond(to: requests.first!, withResult: .success)
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        DLog("peripheralManagerIsReady")
    }
}

// MARK: - PeripheralServiceDelegate
extension GattServer: PeripheralServiceDelegate {
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals: [CBCentral]?) {
        
        peripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: onSubscribedCentrals)
    }
}
