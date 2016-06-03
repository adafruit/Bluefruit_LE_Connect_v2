//
//  StatusManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

class StatusManager : NSObject {
    static let sharedInstance = StatusManager()
    
    enum StatusNotifications : String {
        case DidUpdateStatus = "didUpdateStatus"
    }
        
    enum Status {
        case Updating
        case Connected
        case Connecting
        case Scanning
        case Unknown
        case Resetting
        case Unsupported
        case Unauthorized
        case PoweredOff
        case Ready        
    }
    
    var status = Status.Unknown
    
    // Links to controllers needed to determine status
    weak var peripheralListViewController : PeripheralListViewController?
    weak var updateDialogViewController : UpdateDialogViewController?
    
    override init() {
        super.init()
        
        let defaultCenter = NSNotificationCenter.defaultCenter()
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidUpdateBleState.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidStartScanning.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidStopScanning.rawValue, object: nil)
        
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        defaultCenter.addObserver(self, selector: #selector(StatusManager.updateStatus(_:)), name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
        
    }
    
    deinit {
        let defaultCenter = NSNotificationCenter.defaultCenter()
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidUpdateBleState.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidStartScanning.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.WillConnectToPeripheral.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidConnectToPeripheral.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.WillDisconnectFromPeripheral.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidDisconnectFromPeripheral.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidStopScanning.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidDiscoverPeripheral.rawValue, object: nil)
        defaultCenter.removeObserver(self, name: BleManager.BleNotifications.DidUnDiscoverPeripheral.rawValue, object: nil)
    }
    
    func updateStatus(notification : NSNotification) {
        let bleManager = BleManager.sharedInstance
        let isUpdating = updateDialogViewController != nil
        let isConnected = bleManager.blePeripheralConnected != nil
        let isConnecting = bleManager.blePeripheralConnecting != nil
        let isScanning = bleManager.isScanning
        
        if (isUpdating) {
            status = .Updating
        }
        else if (isConnected) {
            status = .Connected
        }
        else if (isConnecting) {
            status = .Connecting
        }
        else if (isScanning) {
           status = .Scanning
        }
        else {
            if let state = bleManager.centralManager?.state {
                
                switch(state) {
                case .Unknown:
                    status = .Unknown
                case .Resetting:
                    status = .Resetting
                case .Unsupported:
                    status = .Unsupported
                case .Unauthorized:
                    status = .Unauthorized
                case .PoweredOff:
                    status = .PoweredOff
                case .PoweredOn:
                    status = .Ready
                }
            }
        }
        
        NSNotificationCenter.defaultCenter().postNotificationName(StatusNotifications.DidUpdateStatus.rawValue, object: nil);
    }
    
    func statusDescription() -> String {
        
        var message = ""
        let bleManager = BleManager.sharedInstance
        
        switch (status) {
        case .Updating:
            message = "Updating Firmware"
        case .Connected:
            if let name = bleManager.blePeripheralConnected?.name {
                message = "Connected to \(name)"
            }
            else {
                message = "Connected"
            }
        case .Connecting:
            if let name = bleManager.blePeripheralConnecting?.name {
                message = "Connecting to \(name)..."
            }
            else {
                message = "Connecting..."
            }
        case .Scanning:
            message = "Scanning..."
        case .Unknown:
            message = "State unknown, update imminent..."
        case .Resetting:
            message = "The connection with the system service was momentarily lost, update imminent..."
        case .Unsupported:
            message = "Bluetooth Low Energy unsupported"
        case .Unauthorized:
            message = "Unathorized to use Bluetooth Low Energy"
            
        case .PoweredOff:
            message = "Bluetooth is currently powered off"
        case .Ready:
            message = "Status: Ready"
            
        }
        
        return message
    }
    
    func errorDescription() -> String? {
        var errorMessage : String?
        
        switch(status) {
        case .Unsupported:
            errorMessage = "This computer doesn't support Bluetooth Low Energy"
        case .Unauthorized:
            errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
        case .PoweredOff:
            errorMessage = "Bluetooth is currently powered off"
        default:
            errorMessage = nil
        }
        
        return errorMessage
    }
    
    func startConnectionToPeripheral(identifier : String?) {
        peripheralListViewController?.selectRowForPeripheralIdentifier(identifier)
    }
}