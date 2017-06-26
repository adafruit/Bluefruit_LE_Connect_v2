//
//  StatusManager.swift
//  Bluefruit Connect
//
//  Created by Antonio García on 01/10/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Foundation

class StatusManager: NSObject {
    static let sharedInstance = StatusManager()

    enum Status {
        case updating
        case connected
        case connecting
        case scanning
        case unknown
        case resetting
        case unsupported
        case unauthorized
        case poweredOff
        case ready
    }

    var status = Status.unknown

    // Links to controllers needed to determine status
    weak var peripheralListViewController: PeripheralListViewController?
    /* TODO: restore
    weak var updateDialogViewController: UpdateDialogViewController?
*/
    
    override init() {
        super.init()

        registerNotifications(enabled: true)
    }

    deinit {
        registerNotifications(enabled: false)
    }

    // MARK: - BLE Notifications
    private weak var didUpdateBleStateObserver: NSObjectProtocol?
    private weak var didStartScanningObserver: NSObjectProtocol?
    private weak var willConnectToPeripheralObserver: NSObjectProtocol?
    private weak var didConnectToPeripheralObserver: NSObjectProtocol?
    private weak var willDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var didDisconnectFromPeripheralObserver: NSObjectProtocol?
    private weak var didStopScanningObserver: NSObjectProtocol?
    private weak var didDiscoverPeripheralObserver: NSObjectProtocol?
    private weak var didUnDiscoverPeripheralObserver: NSObjectProtocol?

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
        } else {
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
        let isUpdating = false // updateDialogViewController != nil  TODO: restore
        let isConnected = !bleManager.connectedPeripherals().isEmpty
        let isConnecting = !bleManager.connectingPeripherals().isEmpty
        let isScanning = bleManager.isScanning

        if isUpdating {
            status = .updating
        } else if isConnected {
            status = .connected
        } else if isConnecting {
            status = .connecting
        } else if isScanning {
           status = .scanning
        } else {
            if let state = bleManager.centralManager?.state {

                switch state {
                case .unknown:
                    status = .unknown
                case .resetting:
                    status = .resetting
                case .unsupported:
                    status = .unsupported
                case .unauthorized:
                    status = .unauthorized
                case .poweredOff:
                    status = .poweredOff
                case .poweredOn:
                    status = .ready
                }
            }
        }

        NotificationCenter.default.post(name: .didUpdateStatus, object: nil)
    }

    private func listNames(peripherals: [BlePeripheral]) -> String {
        let name = peripherals.reduce("") {
            if $0 == "" {
                return $1.name ?? "<unknown>"
            } else {
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
        case .updating:
            message = "Updating Firmware"
        case .connected:
            let name =  listNames(peripherals: bleManager.connectedPeripherals())
            //if let name = bleManager.blePeripheralConnected?.name {
                message = "Connected to \(name)"
            //}
            //else {
            //    message = "Connected"
            //}
        case .connecting:
            let name =  listNames(peripherals: bleManager.connectingPeripherals())
//            if let name = bleManager.blePeripheralConnecting?.name {
                message = "Connecting to \(name)..."
  //          }
   //         else {
   //             message = "Connecting..."
     //       }
        case .scanning:
            message = "Scanning..."
        case .unknown:
            message = "State unknown, update imminent..."
        case .resetting:
            message = "The connection with the system service was momentarily lost, update imminent..."
        case .unsupported:
            message = "Bluetooth Low Energy unsupported"
        case .unauthorized:
            message = "Unathorized to use Bluetooth Low Energy"
        case .poweredOff:
            message = "Bluetooth is currently powered off"
        case .ready:
            message = "Status: Ready"

        }

        return message
    }

    func errorDescription() -> String? {
        var errorMessage: String?

        switch status {
        case .unsupported:
            errorMessage = "This computer doesn't support Bluetooth Low Energy"
        case .unauthorized:
            errorMessage = "The application is not authorized to use the Bluetooth Low Energy"
        case .poweredOff:
            errorMessage = "Bluetooth is currently powered off"
        default:
            errorMessage = nil
        }

        return errorMessage
    }

    func startConnectionToPeripheral(_ identifier: UUID?) {
        peripheralListViewController?.selectRowForPeripheral(identifier: identifier)
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    private static let kPrefix = Bundle.main.bundleIdentifier!
    static let didUpdateStatus = Notification.Name(kPrefix+".didUpdateStatus")
}
