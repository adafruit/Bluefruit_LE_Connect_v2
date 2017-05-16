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
    weak var peripheralListViewController: PeripheralListViewController?
    weak var updateDialogViewController: UpdateDialogViewController?
    
    override init() {
        super.init()
        
        registerNotifications(enabled: true)
    }
    
    deinit {
        registerNotifications(enabled: false)
    }
    
    // MARK: - BLE Notifications
    private var didUpdateBleStateObserver: NSObjectProtocol?
    private var didStartScanningObserver: NSObjectProtocol?
    private var willConnectToPeripheralObserver: NSObjectProtocol?
    private var didConnectToPeripheralObserver: NSObjectProtocol?
    private var willDisconnectFromPeripheralObserver: NSObjectProtocol?
    private var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    private var didStopScanningObserver: NSObjectProtocol?
    private var didDiscoverPeripheralObserver: NSObjectProtocol?
    private var didUnDiscoverPeripheralObserver: NSObjectProtocol?
    
    private func registerNotifications(enabled: Bool) {
        let notificationCenter = NotificationCenter.default
        if enabled {
            didUpdateBleStateObserver = notificationCenter.addObserver(forName: .didUpdateBleState, object: nil, queue: .main, using: updateStatus)
            didStartScanningObserver = notificationCenter.addObserver(forName: .didStartScanning, object: nil, queue: .main, using: updateStatus)
            willConnectToPeripheralObserver = notificationCenter.addObserver(forName: .willConnectToPeripheral, object: nil, queue: .main, using: updateStatus)
            didConnectToPeripheralObserver = notificationCenter.addObserver(forName: .didConnectToPeripheral, object: nil, queue: .main, using: updateStatus)
            willDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .willDisconnectFromPeripheral, object: nil, queue: .main, using: updateStatus)
            didDisconnectFromPeripheralObserver = notificationCenter.addObserver(forName: .didDisconnectFromPeripheral, object: nil, queue: .main, using: updateStatus)
            didStopScanningObserver = notificationCenter.addObserver(forName: .didStopScanning, object: nil, queue: .main, using: updateStatus)
            didDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didDiscoverPeripheral, object: nil, queue: .main, using: updateStatus)
            didUnDiscoverPeripheralObserver = notificationCenter.addObserver(forName: .didUnDiscoverPeripheral, object: nil, queue: .main, using: updateStatus)
        }
        else {
            if let didUpdateBleStateObserver = didUpdateBleStateObserver {notificationCenter.removeObserver(didUpdateBleStateObserver)}
            if let didStartScanningObserver = didStartScanningObserver {notificationCenter.removeObserver(didStartScanningObserver)}
            if let willConnectToPeripheralObserver = willConnectToPeripheralObserver {notificationCenter.removeObserver(willConnectToPeripheralObserver)}
            if let didConnectToPeripheralObserver = didConnectToPeripheralObserver {notificationCenter.removeObserver(didConnectToPeripheralObserver)}
            if let willDisconnectFromPeripheralObserver = willDisconnectFromPeripheralObserver {notificationCenter.removeObserver(willDisconnectFromPeripheralObserver)}
            if let didDisconnectFromPeripheralObserver = didDisconnectFromPeripheralObserver {notificationCenter.removeObserver(didDisconnectFromPeripheralObserver)}
            if let didStopScanningObserver = didStopScanningObserver {notificationCenter.removeObserver(didStopScanningObserver)}
            if let didDiscoverPeripheralObserver = didDiscoverPeripheralObserver {notificationCenter.removeObserver(didDiscoverPeripheralObserver)}
            if let didUnDiscoverPeripheralObserver = didUnDiscoverPeripheralObserver {notificationCenter.removeObserver(didUnDiscoverPeripheralObserver)}
        }
    }

    
    func updateStatus(notification: Notification) {
        let bleManager = BleManager.sharedInstance
        let isUpdating = updateDialogViewController != nil
        let isConnected = bleManager.blePeripheralConnected != nil
        let isConnecting = bleManager.blePeripheralConnecting != nil
        let isScanning = bleManager.isScanning
        
        if isUpdating {
            status = .Updating
        }
        else if isConnected {
            status = .Connected
        }
        else if isConnecting {
            status = .Connecting
        }
        else if isScanning {
           status = .Scanning
        }
        else {
            if let state = bleManager.centralManager?.state {
                
                switch(state) {
                case .unknown:
                    status = .Unknown
                case .resetting:
                    status = .Resetting
                case .unsupported:
                    status = .Unsupported
                case .unauthorized:
                    status = .Unauthorized
                case .poweredOff:
                    status = .PoweredOff
                case .poweredOn:
                    status = .Ready
                }
            }
        }
        
        NotificationCenter.default.post(name: .didUpdateStatus, object: nil);
    }
    
    private func listNames(peripherals: [BlePeripheral]) -> String {
        let name = peripherals.reduce("") {
            if $0 == "" {
                return $1.name ?? "<unknown>"
            }
            else {
                return $0 + ", " + ($1.name ?? "<unknown>")
            }
            //                $0 == "" ? $1.name : $0 + ", " + ($1.name ?? "<unknown>")
        }
        return name
    }
    
    func statusDescription() -> String {
        
        var message = ""
        let bleManager = BleManager.sharedInstance
        
        switch status {
        case .Updating:
            message = "Updating Firmware"
        case .Connected:
            let name =  listNames(peripherals: bleManager.connectedPeripherals())
            //if let name = bleManager.blePeripheralConnected?.name {
                message = "Connected to \(name)"
            //}
            //else {
            //    message = "Connected"
            //}
        case .Connecting:
            let name =  listNames(peripherals: bleManager.connectingPeripherals())
//            if let name = bleManager.blePeripheralConnecting?.name {
                message = "Connecting to \(name)..."
  //          }
   //         else {
   //             message = "Connecting..."
     //       }
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
        var errorMessage: String?
        
        switch status {
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
    
    func startConnectionToPeripheral(identifier: String?) {
        peripheralListViewController?.selectRowForPeripheralIdentifier(identifier)
    }
}


// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    static let didUpdateStatus = Notification.Name(kPrefix+".didUpdateStatus")
}
